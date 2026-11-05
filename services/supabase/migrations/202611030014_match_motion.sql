begin;
-- New rooms/rematches opt into faster motion; unreserved legacy rooms stay slow.
alter table lakebound_private.match_rooms add column motion_interval numeric not null default 2.0 check(motion_interval in (2.0,0.334));
alter table lakebound_private.match_rooms alter column motion_interval set default 0.334;
-- Keep old reservations; top up the one currently leased live room before upgrading.
do $upgrade$
declare extra bigint; today date:=(clock_timestamp() at time zone 'UTC')::date; used bigint; rooms integer;
begin
 perform pg_advisory_xact_lock(741152);
 select count(*) into rooms from lakebound_private.match_rooms r where exists(select 1 from lakebound_private.match_leases l where l.room_id=r.id and l.expires_at>clock_timestamp()) and r.phase in ('lobby','loading','countdown','running') and (r.ends_at is null or r.ends_at>clock_timestamp());
 if rooms>1 then raise exception 'finish_extra_rooms_before_motion_upgrade'; end if;
 select coalesce(sum((r.duration+180)*75),0) into extra from lakebound_private.match_rooms r where exists(select 1 from lakebound_private.match_leases l where l.room_id=r.id and l.expires_at>clock_timestamp()) and r.phase in ('lobby','loading','countdown','running') and (r.ends_at is null or r.ends_at>clock_timestamp());
 select coalesce(sum(reserved),0) into used from lakebound_private.match_budget where month>=today-32;
 if extra>0 and used+extra>(select monthly_events from lakebound_private.match_limits where singleton) then raise exception 'insufficient_motion_upgrade_budget'; end if;
 if extra>0 then
  insert into lakebound_private.match_budget values(today,extra) on conflict(month) do update set reserved=match_budget.reserved+excluded.reserved;
  update lakebound_private.match_rooms r set motion_interval=0.334 where exists(select 1 from lakebound_private.match_leases l where l.room_id=r.id and l.expires_at>clock_timestamp()) and r.phase in ('lobby','loading','countdown','running') and (r.ends_at is null or r.ends_at>clock_timestamp());
 end if;
end $upgrade$;
update lakebound_private.match_limits set max_rooms=1,max_players=5;
do $patch$
declare d text; marker text:=$s$cost:=(chosen_duration+180)*15;$s$;
begin
 d:=pg_get_functiondef('lakebound_private.match_admission_v2(jsonb)'::regprocedure);
 if strpos(d,marker)=0 or strpos(d,'insert into lakebound_private.match_budget values(month_key,cost)')=0 then raise exception 'unexpected_motion_admission'; end if;
 d:=replace(d,marker,$s$cost:=(chosen_duration+180)*90;$s$);
 d:=replace(d,$s$insert into lakebound_private.match_budget values(month_key,cost)$s$,$s$update lakebound_private.match_rooms set motion_interval=0.334 where id=(result->>'id')::uuid;
  result:=lakebound_private.match_snapshot((result->>'id')::uuid);
  insert into lakebound_private.match_budget values(month_key,cost)$s$);
 execute d;
 d:=pg_get_functiondef('lakebound_private.match_snapshot(uuid)'::regprocedure);
 if strpos(d,$s$'pose_interval',2.0$s$)=0 then raise exception 'unexpected_motion_snapshot'; end if;
 d:=replace(d,$s$'pose_interval',2.0$s$,$s$'pose_interval',r.motion_interval$s$);
 execute d;
end $patch$;
notify pgrst,'reload schema';
commit;
