begin;
-- Four small rooms, not a larger mesh. Keep historical reservations intact.
select pg_advisory_xact_lock(741152);
alter table lakebound_private.match_rooms alter column motion_interval set default 2.0;
update lakebound_private.match_limits set max_rooms=4,max_players=20;
do $patch$
declare d text; marker text:=$s$cost:=(chosen_duration+180)*90;$s$;
 gate text:=$s$if reserve_round then
  if not lim.accepts_new$s$;
begin
 d:=pg_get_functiondef('lakebound_private.match_admission_v2(jsonb)'::regprocedure);
 if strpos(d,marker)=0 or strpos(d,$s$set motion_interval=0.334$s$)=0 or strpos(d,gate)=0 then
  raise exception 'unexpected_capacity_admission';
 end if;
 d:=replace(d,marker,$s$cost:=(chosen_duration+180)*15;$s$);
 d:=replace(d,$s$set motion_interval=0.334$s$,$s$set motion_interval=2.0$s$);
 -- An old fast room already reserves 90 events/s. Do not mix it with extra
 -- rooms until it ends. New slow-fallback rooms reserve 15 each (60 for four).
 d:=replace(d,gate,$s$if reserve_round then
  if (select coalesce(sum(case when r.motion_interval<2.0 then 90 else 15 end),0)
      from lakebound_private.match_rooms r
      where r.id is distinct from desired and exists(
       select 1 from lakebound_private.match_leases l where l.room_id=r.id and l.expires_at>stamp)) + 15 > 90 then
   return jsonb_build_object('error','capacity_full');
  end if;
  if not lim.accepts_new$s$);
 execute d;
end $patch$;
-- Owner/server-only operational view: no identities, credentials or fish data.
create function public.lakebound_capacity_status() returns jsonb
language sql volatile security definer set search_path='' as $status$
 select jsonb_build_object(
  'target_monthly_users',300,'max_rooms',l.max_rooms,'max_players',l.max_players,
  'accepts_new',l.accepts_new,'rolling_days',33,
  'reserved_events',b.used,'event_budget',l.monthly_events,
  'remaining_events',greatest(0,l.monthly_events-b.used),
  'active_players',(select count(*) from lakebound_private.match_leases x join lakebound_private.match_rooms r on r.id=x.room_id
   where x.expires_at>clock_timestamp() and r.phase in ('lobby','loading','countdown','running') and (r.ends_at is null or r.ends_at>clock_timestamp())),
  'active_rooms',(select count(distinct x.room_id) from lakebound_private.match_leases x join lakebound_private.match_rooms r on r.id=x.room_id
   where x.expires_at>clock_timestamp() and r.phase in ('lobby','loading','countdown','running') and (r.ends_at is null or r.ends_at>clock_timestamp())),
  'new_round_events_10min',11700,'new_fallback_seconds',2.0,
  'turn_issuance_attempts_today',(select coalesce(sum(attempts),0) from lakebound_private.turn_credentials where requested_at>=date_trunc('day',clock_timestamp()))
 ) from lakebound_private.match_limits l cross join lateral (
  select coalesce(sum(reserved),0) used from lakebound_private.match_budget
  where month>=(clock_timestamp() at time zone 'UTC')::date-32
 ) b where l.singleton
$status$;
revoke all on function public.lakebound_capacity_status() from public,anon,authenticated;
grant execute on function public.lakebound_capacity_status() to service_role;
notify pgrst,'reload schema';
commit;
