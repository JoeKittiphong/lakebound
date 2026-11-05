begin;
alter table lakebound_private.match_rooms drop constraint match_rooms_duration_check;
alter table lakebound_private.match_rooms add constraint match_rooms_duration_check check(duration in (180,300,600,900,1200));
-- Existing rounds retain their original top-three scoring until a new room is created.
alter table lakebound_private.match_rooms add column rule text not null default 'legacy_top3'
 check(rule in ('legacy_top3','species_total','total_weight','biggest_fish'));
alter table lakebound_private.match_rooms alter column rule set default 'total_weight';
alter table lakebound_private.match_rooms add column target_species text references lakebound_private.species;
alter table lakebound_private.match_rooms add constraint match_target_rule check((rule='species_total')=(target_species is not null));
create table lakebound_private.match_species(map_id text, species_id text references lakebound_private.species, primary key(map_id,species_id));
create table lakebound_private.match_limits(
 singleton boolean primary key default true check(singleton),
 max_rooms integer not null default 4 check(max_rooms between 1 and 4),
 max_players integer not null default 20 check(max_players between 2 and 20),
 monthly_events bigint not null default 1500000 check(monthly_events between 0 and 1500000),
 accepts_new boolean not null default true
);
insert into lakebound_private.match_limits(singleton) values(true);
create table lakebound_private.match_leases(
 auth_id uuid primary key references lakebound_private.accounts(auth_id),
 player_id text not null unique references lakebound_private.players,
 room_id uuid not null references lakebound_private.match_rooms,
 expires_at timestamptz not null
);
create index match_leases_room on lakebound_private.match_leases(room_id);
create table lakebound_private.match_budget(month date primary key, reserved bigint not null default 0);
create table lakebound_private.match_requests(auth_id uuid primary key references lakebound_private.accounts(auth_id),
 window_at timestamptz not null, requests integer not null);
alter table lakebound_private.match_species enable row level security;
alter table lakebound_private.match_limits enable row level security;
alter table lakebound_private.match_leases enable row level security;
alter table lakebound_private.match_budget enable row level security;
alter table lakebound_private.match_requests enable row level security;
revoke all on lakebound_private.match_species,lakebound_private.match_limits,lakebound_private.match_leases,
 lakebound_private.match_budget,lakebound_private.match_requests from public,anon,authenticated;

-- Patch only the two known statements; refuse unexpected engine revisions.
do $patch$
declare d text; old_insert text:=$s$insert into lakebound_private.match_rooms(code,host,map_id) values(rc,pid,payload->>'map')$s$;
begin
 d:=pg_get_functiondef('lakebound_private.lakebound_matches(jsonb)'::regprocedure);
 if strpos(d,old_insert)=0 or strpos(d,$s$ends_at=stamp+interval '605 seconds'$s$)=0 then raise exception 'unexpected_match_engine'; end if;
 d:=replace(d,old_insert,$s$insert into lakebound_private.match_rooms(code,host,map_id,duration,rule,target_species) values(rc,pid,payload->>'map',coalesce((payload->>'duration')::integer,600),coalesce(payload->>'rule','total_weight'),nullif(payload->>'target_species',''))$s$);
 d:=replace(d,$s$ends_at=stamp+interval '605 seconds'$s$,$s$ends_at=stamp+interval '5 seconds'+make_interval(secs=>r.duration)$s$);
 execute d;
end $patch$;

create or replace function lakebound_private.match_snapshot(rid uuid) returns jsonb
language sql stable security definer set search_path='' as $snapshot$
 with scored as (
  select m.*,p.player_name,r.rule,coalesce(s.total,0) total,coalesce(s.best,'{}'::integer[]) best
  from lakebound_private.match_members m join lakebound_private.players p using(player_id)
  join lakebound_private.match_rooms r on r.id=m.room_id
  left join lateral (
   select case when r.rule='biggest_fish' then max(grams)::bigint else sum(grams)::bigint end total,
    (array_agg(grams order by grams desc,catch_id))[1:3] best
   from (
    select grams,catch_id from lakebound_private.match_catches c
    where c.room_id=m.room_id and c.player_id=m.player_id and (r.rule<>'species_total' or c.species_id=r.target_species)
    order by grams desc,catch_id limit case when r.rule='legacy_top3' then 3 else 200 end
   ) catches
  ) s on true where m.room_id=rid
 ), ranked as (
  select *,rank() over(order by total desc,case when rule='legacy_top3' then best else '{}'::integer[] end desc) place from scored
 )
 select jsonb_build_object('schema',1,'id',r.id,'code',r.code,'host',r.host,'map',r.map_id,
  'phase',r.phase,'seed',r.seed,'round_id',r.round_id,'duration',r.duration,'rule',r.rule,'target_species',coalesce(r.target_species,''),
  'server_time',extract(epoch from clock_timestamp()),'starts_at',coalesce(extract(epoch from r.starts_at),0),
  'ends_at',coalesce(extract(epoch from r.ends_at),0),'pose_interval',2.0,'poll_interval',5.0,
  'members',coalesce((select jsonb_agg(jsonb_build_object('id',player_id,'name',player_name,'ready',ready,'loaded',loaded,
   'departed',departed,'online',seen_at>clock_timestamp()-interval '20 seconds','grams',total,'best',to_jsonb(best),'rank',place)
   order by place,joined_at,player_id) from ranked),'[]'::jsonb))
 from lakebound_private.match_rooms r where r.id=rid
$snapshot$;

create or replace function public.lakebound_matches(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' set lock_timeout='2s' as $gateway$
declare uid uuid:=auth.uid(); pid text:=payload->>'player_id'; op text:=payload->>'op'; stamp timestamptz:=clock_timestamp();
 lim lakebound_private.match_limits%rowtype; rr lakebound_private.match_rooms%rowtype;
 result jsonb; existing_room uuid; desired uuid; current_count integer; room_count integer; request_count integer;
 new_room boolean:=false; reserve_round boolean:=false; cost bigint:=0; month_key date; used bigint;
 chosen_duration integer; chosen_rule text; chosen_species text;
begin
 if uid is null or coalesce(auth.jwt()->'app_metadata'->>'provider','')<>'google'
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then return jsonb_build_object('error','google_login_required'); end if;
 if jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>4096 then return jsonb_build_object('error','invalid_payload'); end if;
 if not exists(select 1 from lakebound_private.accounts where auth_id=uid and player_id=pid) then return jsonb_build_object('error','account_mismatch'); end if;
 insert into lakebound_private.match_requests values(uid,stamp,1) on conflict(auth_id) do update set
  requests=case when excluded.window_at-match_requests.window_at>=interval '1 second' then 1 else match_requests.requests+1 end,
  window_at=case when excluded.window_at-match_requests.window_at>=interval '1 second' then excluded.window_at else match_requests.window_at end
  returning requests into request_count;
 if request_count>6 then return jsonb_build_object('error','rate_limited'); end if;
 -- One short admission transaction serializes global capacity and monthly reservations.
 perform pg_advisory_xact_lock(741152);
 select * into lim from lakebound_private.match_limits where singleton;
 delete from lakebound_private.match_leases l using lakebound_private.match_rooms r
  where l.room_id=r.id and (l.expires_at<=stamp or r.phase in ('finished','cancelled') or (r.ends_at is not null and r.ends_at<=stamp));
 if op in ('create','join','quick_join') then
  select r.id into existing_room from lakebound_private.match_rooms r join lakebound_private.match_members m on m.room_id=r.id
   where m.player_id=pid and not m.departed and r.phase in ('lobby','loading','countdown','running')
   and r.created_at>stamp-interval '2 hours' and (r.ends_at is null or r.ends_at>stamp) limit 1;
 end if;
 if op='quick_join' then
  if existing_room is not null then
   desired:=existing_room; payload:=payload||jsonb_build_object('op','state','room_id',desired); op:='state';
  else
   select r.* into rr from lakebound_private.match_rooms r
    where r.phase='lobby' and r.created_at>stamp-interval '2 hours'
    and exists(select 1 from lakebound_private.match_leases l join lakebound_private.match_members m on m.room_id=l.room_id and m.player_id=l.player_id
     where l.room_id=r.id and l.player_id=r.host and l.expires_at>stamp and not m.departed and m.seen_at>stamp-interval '20 seconds')
    and (select count(*) from lakebound_private.match_members m where m.room_id=r.id and not m.departed)<5
    order by r.created_at,r.id limit 1 for update;
   if rr.id is null then return jsonb_build_object('error','no_open_rooms'); end if;
   desired:=rr.id; payload:=payload||jsonb_build_object('op','join','code',rr.code); op:='join';
  end if;
 end if;
 if op='create' then
  desired:=existing_room; new_room:=desired is null;
  if new_room then
   if jsonb_typeof(payload->'duration') is not null and jsonb_typeof(payload->'duration')<>'number' then return jsonb_build_object('error','invalid_duration'); end if;
   if coalesce((payload->>'duration')::numeric,600) not in (180,300,600,900,1200) then return jsonb_build_object('error','invalid_duration'); end if;
   chosen_duration:=coalesce((payload->>'duration')::numeric,600)::integer;
   chosen_rule:=coalesce(payload->>'rule','total_weight'); chosen_species:=nullif(payload->>'target_species','');
   if chosen_rule not in ('species_total','total_weight','biggest_fish') then return jsonb_build_object('error','invalid_rule'); end if;
   if (chosen_rule='species_total' and not exists(select 1 from lakebound_private.match_species where map_id=payload->>'map' and species_id=chosen_species))
    or (chosen_rule<>'species_total' and chosen_species is not null) then return jsonb_build_object('error','invalid_target_species'); end if;
   reserve_round:=true;
  end if;
 elsif op='join' then
  select * into rr from lakebound_private.match_rooms where code=payload->>'code'; desired:=rr.id;
 else
  desired:=(payload->>'room_id')::uuid;
 end if;
 if desired is not null then select * into rr from lakebound_private.match_rooms where id=desired; end if;
 if op='rematch' and rr.phase in ('finished','cancelled') and rr.host=pid then reserve_round:=true; chosen_duration:=rr.duration; end if;
 if op<>'leave' and (new_room or reserve_round or (rr.phase in ('lobby','loading','countdown','running') and (rr.ends_at is null or rr.ends_at>stamp))) then
  if not lim.accepts_new and op in ('create','join','rematch') then return jsonb_build_object('error','capacity_full'); end if;
  select count(*),count(distinct room_id) into current_count,room_count from lakebound_private.match_leases;
  if not exists(select 1 from lakebound_private.match_leases where auth_id=uid) and current_count>=lim.max_players then return jsonb_build_object('error','capacity_full'); end if;
  if (new_room or not exists(select 1 from lakebound_private.match_leases where room_id=desired)) and room_count>=lim.max_rooms then return jsonb_build_object('error','capacity_full'); end if;
 end if;
 if reserve_round then
  if not lim.accepts_new then return jsonb_build_object('error','capacity_full'); end if;
  cost:=(chosen_duration+180)*15; -- Pessimistic five-player room, 2s poses, control/join margin; never refund unused reservations.
  month_key:=date_trunc('month',stamp at time zone 'UTC')::date;
  select reserved into used from lakebound_private.match_budget where month=month_key;
  if coalesce(used,0)+cost>lim.monthly_events then return jsonb_build_object('error','monthly_capacity_reached'); end if;
 end if;
 result:=lakebound_private.lakebound_matches(payload);
 if result ? 'error' or not(result ? 'id') then return result; end if;
 if reserve_round then
  insert into lakebound_private.match_budget values(month_key,cost) on conflict(month) do update set reserved=match_budget.reserved+excluded.reserved;
 end if;
 if op='leave' then delete from lakebound_private.match_leases where auth_id=uid;
 elsif result->>'phase' in ('lobby','loading','countdown','running') then
  insert into lakebound_private.match_leases values(uid,pid,(result->>'id')::uuid,stamp+interval '75 seconds')
   on conflict(auth_id) do update set room_id=excluded.room_id,expires_at=excluded.expires_at;
 end if;
 if result->>'phase' in ('finished','cancelled') then delete from lakebound_private.match_leases where room_id=(result->>'id')::uuid; end if;
 return result;
exception when lock_not_available or deadlock_detected then return jsonb_build_object('error','busy_retry');
 when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('error','invalid_payload');
end $gateway$;

create or replace function public.lakebound_match_channel(topic text) returns boolean
language sql stable security definer set search_path='' as $channel$
 select exists(select 1 from lakebound_private.match_members m join lakebound_private.match_rooms r on r.id=m.room_id
  join lakebound_private.match_leases l on l.room_id=m.room_id and l.player_id=m.player_id and l.auth_id=m.auth_id
  where m.auth_id=auth.uid() and not m.departed and topic='match:'||r.id::text
  and l.expires_at>clock_timestamp() and r.phase not in ('cancelled') and r.created_at>clock_timestamp()-interval '2 hours')
$channel$;
insert into lakebound_private.match_species values
('river','tilapia'),
('river','snakehead'),
('river','catfish'),
('river','golden_barb'),
('river','gourami'),
('river','featherback'),
('river','betta'),
('river','lionhead_goldfish'),
('river','koi'),
('river','arowana'),
('river','tigerfish'),
('river','hampala'),
('river','giant_catfish'),
('river','redtail_catfish'),
('river','freshwater_eel'),
('river','freshwater_stingray'),
('river','iridescent_shark'),
('river','seven_striped_barb'),
('river','rohu'),
('river','asian_redtail_catfish'),
('river','yellow_mystus'),
('river','crystal_eyed_catfish'),
('river','bronze_featherback'),
('river','black_sharkminnow'),
('river','white_sheatfish'),
('river','black_sheatfish'),
('river','smallscale_mud_carp'),
('river','giant_pangasius'),
('river','red_tilapia'),
('river','climbing_perch'),
('river','java_barb'),
('river','three_spot_gourami'),
('river','snakeskin_gourami'),
('river','asian_swamp_eel'),
('river','siamese_gourami'),
('river','walking_catfish'),
('river','pearl_gourami'),
('river','marbled_sleeper'),
('river','ghost_glass_catfish'),
('river','wild_betta'),
('river','tinfoil_barb'),
('river','grass_carp'),
('river','silver_carp'),
('river','bighead_carp'),
('river','red_cheeked_barb'),
('river','fire_eel'),
('river','tire_track_eel'),
('river','red_bellied_pacu'),
('lotus_marsh','tilapia'),
('lotus_marsh','red_tilapia'),
('lotus_marsh','climbing_perch'),
('lotus_marsh','malayan_leaffish'),
('lotus_marsh','catfish'),
('lotus_marsh','walking_catfish'),
('lotus_marsh','java_barb'),
('lotus_marsh','golden_barb'),
('lotus_marsh','three_spot_gourami'),
('lotus_marsh','snakeskin_gourami'),
('lotus_marsh','snakehead'),
('lotus_marsh','asian_swamp_eel'),
('lotus_marsh','siamese_gourami'),
('lotus_marsh','elder_snakehead'),
('forest_stream','blue_mahseer'),
('forest_stream','red_mahseer'),
('forest_stream','thai_mahseer'),
('forest_stream','hampala'),
('forest_stream','burmese_trout'),
('forest_stream','giant_danio'),
('forest_stream','fire_eel'),
('forest_stream','tire_track_eel'),
('forest_stream','freshwater_garfish'),
('forest_stream','dwarf_snakehead'),
('forest_stream','mountain_barb'),
('forest_stream','boeseman_croaker'),
('forest_stream','goonch'),
('forest_stream','golden_tor'),
('forest_stream','arowana'),
('forest_stream','silver_arowana'),
('forest_stream','alligator_gar'),
('forest_stream','emperor_snakehead'),
('forest_stream','cobra_snakehead'),
('forest_stream','wild_betta'),
('forest_stream','torrent_catfish'),
('forest_stream','giant_luciosoma'),
('forest_stream','black_swamp_spiny_eel'),
('forest_stream','marbled_sleeper'),
('forest_stream','pearl_gourami'),
('forest_stream','tigerfish'),
('forest_stream','ghost_glass_catfish'),
('forest_stream','mythic_golden_dragon'),
('wild_reservoir','giant_snakehead'),
('wild_reservoir','spotted_hampala'),
('wild_reservoir','giant_danionin'),
('wild_reservoir','red_bellied_pacu'),
('wild_reservoir','royal_featherback'),
('wild_reservoir','sultan_fish'),
('wild_reservoir','tinfoil_barb'),
('wild_reservoir','bighead_carp'),
('wild_reservoir','silver_carp'),
('wild_reservoir','grass_carp'),
('wild_reservoir','red_cheeked_barb'),
('wild_reservoir','black_ear_catfish'),
('wild_reservoir','gourami'),
('wild_reservoir','red_fin_titan'),
('mangrove_estuary','barramundi'),
('mangrove_estuary','mangrove_snapper'),
('mangrove_estuary','black_seabream'),
('mangrove_estuary','archerfish'),
('mangrove_estuary','river_barracuda'),
('mangrove_estuary','marine_catfish'),
('mangrove_estuary','fourfinger_threadfin'),
('mangrove_estuary','grey_mullet'),
('mangrove_estuary','silver_pomfret'),
('mangrove_estuary','giant_mudskipper'),
('mangrove_estuary','striped_eel_catfish'),
('mangrove_estuary','estuary_grouper'),
('mangrove_estuary','toli_shad'),
('mangrove_estuary','silver_titan'),
('coral_coast','giant_trevally'),
('coral_coast','bigeye_trevally'),
('coral_coast','yellowfin_tuna'),
('coral_coast','bigeye_tuna'),
('coral_coast','spanish_mackerel'),
('coral_coast','giant_grouper'),
('coral_coast','coral_trout'),
('coral_coast','parrotfish'),
('coral_coast','mahi_mahi'),
('coral_coast','cobia'),
('coral_coast','great_barracuda'),
('coral_coast','diamond_trevally'),
('coral_coast','wahoo'),
('coral_coast','bluefin_tuna'),
('coral_coast','sailfish');
commit;
