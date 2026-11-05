-- Small private synchronous matches. No dedicated game server; no economy rewards.
begin;
create table lakebound_private.match_rooms (
 id uuid primary key default gen_random_uuid(), code text not null unique,
 host text not null references lakebound_private.players,
 map_id text not null check(map_id in ('river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast')),
 phase text not null default 'lobby' check(phase in ('lobby','loading','countdown','running','finished','cancelled')),
 seed integer not null default floor(random()*2147483647), round_id uuid not null default gen_random_uuid(),
 created_at timestamptz not null default clock_timestamp(),
 loading_at timestamptz, starts_at timestamptz, ends_at timestamptz,
 duration integer not null default 600 check(duration=600)
);
create table lakebound_private.match_members (
 room_id uuid references lakebound_private.match_rooms on delete cascade,
 player_id text references lakebound_private.players,
 auth_id uuid not null, ready boolean not null default false, loaded boolean not null default false,
 departed boolean not null default false, joined_at timestamptz not null default clock_timestamp(),
 seen_at timestamptz not null default clock_timestamp(), primary key(room_id,player_id)
);
create index match_members_auth on lakebound_private.match_members(auth_id,room_id);
create table lakebound_private.match_catches (
 room_id uuid not null, player_id text not null, catch_id text not null,
 species_id text not null references lakebound_private.species,
 grams integer not null check(grams between 1 and 1000000000),
 received_at timestamptz not null default clock_timestamp(),
 primary key(room_id,player_id,catch_id),
 foreign key(room_id,player_id) references lakebound_private.match_members
);
alter table lakebound_private.match_rooms enable row level security;
alter table lakebound_private.match_members enable row level security;
alter table lakebound_private.match_catches enable row level security;
revoke all on lakebound_private.match_rooms,lakebound_private.match_members,lakebound_private.match_catches from public,anon,authenticated;

create function lakebound_private.match_snapshot(rid uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with scores as (
  select m.*, p.player_name, coalesce(s.total,0) total, coalesce(s.best,'{}'::integer[]) best
  from lakebound_private.match_members m join lakebound_private.players p using(player_id)
  left join lateral (
   select sum(grams)::bigint total,array_agg(grams order by grams desc) best from (
    select grams from lakebound_private.match_catches c where c.room_id=m.room_id and c.player_id=m.player_id
    order by grams desc,catch_id limit 3
   ) top3
  ) s on true where m.room_id=rid
 ), ranked as (
  select *, rank() over(order by total desc,best desc) place from scores
 )
 select jsonb_build_object('schema',1,'id',r.id,'code',r.code,'host',r.host,'map',r.map_id,
  'phase',r.phase,'seed',r.seed,'round_id',r.round_id,'server_time',extract(epoch from clock_timestamp()),
  'starts_at',coalesce(extract(epoch from r.starts_at),0),'ends_at',coalesce(extract(epoch from r.ends_at),0),
  'pose_interval',greatest(1.0/3.0,coalesce((select sum(n*n)/60.0 from (
   select count(*)::numeric n from lakebound_private.match_members mm
   join lakebound_private.match_rooms rr on rr.id=mm.room_id
   where not mm.departed and mm.seen_at>clock_timestamp()-interval '20 seconds'
   and rr.phase in ('loading','countdown','running') group by mm.room_id
  ) traffic),0)),
  'members',coalesce((select jsonb_agg(jsonb_build_object('id',player_id,'name',player_name,
   'ready',ready,'loaded',loaded,'departed',departed,'online',seen_at>clock_timestamp()-interval '20 seconds',
   'grams',total,'best',to_jsonb(best),'rank',place) order by place,joined_at,player_id) from ranked),'[]'::jsonb))
 from lakebound_private.match_rooms r where r.id=rid
$$;
revoke all on function lakebound_private.match_snapshot(uuid) from public,anon,authenticated;

-- Called by private Realtime RLS. Only room members may join its UUID topic.
create function public.lakebound_match_channel(topic text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from lakebound_private.match_members m
 join lakebound_private.match_rooms r on r.id=m.room_id
 where m.auth_id=auth.uid() and not m.departed and topic='match:'||r.id::text
 and r.phase not in ('cancelled') and r.created_at>clock_timestamp()-interval '1 day')
$$;
revoke all on function public.lakebound_match_channel(text) from public,anon;
grant execute on function public.lakebound_match_channel(text) to authenticated;
create policy lakebound_match_receive on realtime.messages for select to authenticated
 using(extension in ('broadcast','presence') and public.lakebound_match_channel(realtime.topic()));
create policy lakebound_match_send on realtime.messages for insert to authenticated
 with check(extension in ('broadcast','presence') and public.lakebound_match_channel(realtime.topic()));

create function public.lakebound_matches(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' as $$
declare
 pid text:=payload->>'player_id'; secret text:=payload->>'token'; op text:=payload->>'op';
 rid uuid; r lakebound_private.match_rooms%rowtype; m lakebound_private.match_members%rowtype;
 auth_result jsonb; current_room uuid; n integer; g integer; cid text; sid text; prev lakebound_private.match_catches%rowtype;
 stamp timestamptz; rc text;
begin
 if jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>4096 or auth.uid() is null
 then raise exception 'authentication_required'; end if;
 -- Existing guest identity remains the source of identity, never user-supplied JWT metadata.
 auth_result:=public.lakebound_rankings(jsonb_build_object('player_id',pid,'token',secret,
  'player_name',payload->>'player_name','catches','[]'::jsonb));
 if auth_result ? 'error' then return auth_result; end if;
 -- Rankings serializes this player; room row locks serialize start/join/catch/leave.
 if op='create' or op='join' then
  select mm.room_id into current_room from lakebound_private.match_members mm
   join lakebound_private.match_rooms rr on rr.id=mm.room_id
   where mm.player_id=pid and not mm.departed and rr.phase in ('lobby','loading','countdown','running')
   and rr.created_at>clock_timestamp()-interval '2 hours'
   and (rr.ends_at is null or rr.ends_at>clock_timestamp()) limit 1;
  if current_room is not null then
   if (op='join' and exists(select 1 from lakebound_private.match_rooms where id=current_room and code=upper(payload->>'code')))
    or (op='create' and exists(select 1 from lakebound_private.match_rooms where id=current_room and map_id=payload->>'map'))
   then update lakebound_private.match_members set auth_id=auth.uid(),seen_at=clock_timestamp() where room_id=current_room and player_id=pid;
    return lakebound_private.match_snapshot(current_room);
   end if;
   raise exception 'already_in_match';
  end if;
 end if;
 if op='create' then
  if payload->>'map' not in ('river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast') or not(payload ? 'map') then raise exception 'invalid_map'; end if;
  -- 40 random bits, checked unique; codes are discovery, not authorization.
  rc:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  insert into lakebound_private.match_rooms(code,host,map_id) values(rc,pid,payload->>'map') returning id into rid;
  insert into lakebound_private.match_members(room_id,player_id,auth_id) values(rid,pid,auth.uid());
 else
  if op='join' then
   if payload->>'code' !~ '^[A-Za-z0-9]{10}$' then raise exception 'room_not_found'; end if;
   select * into r from lakebound_private.match_rooms where code=upper(payload->>'code') for update;
  else
   select * into r from lakebound_private.match_rooms where id=(payload->>'room_id')::uuid for update;
  end if;
  if r.id is null then raise exception 'room_not_found'; end if;
  rid:=r.id; stamp:=clock_timestamp();
  if r.phase='lobby' and r.created_at<stamp-interval '2 hours' then
   update lakebound_private.match_rooms set phase='cancelled' where id=rid; r.phase:='cancelled';
  end if;
  if r.phase='loading' and r.loading_at<stamp-interval '120 seconds' then
   update lakebound_private.match_rooms set phase='cancelled' where id=rid; r.phase:='cancelled';
  end if;
  if r.phase='countdown' and stamp>=r.starts_at then
   update lakebound_private.match_rooms set phase='running' where id=rid; r.phase:='running';
  end if;
  if r.phase='running' and stamp>=r.ends_at then
   update lakebound_private.match_rooms set phase='finished' where id=rid; r.phase:='finished';
  end if;
  if op='join' then
   if r.phase<>'lobby' then raise exception 'room_locked'; end if;
   select count(*) into n from lakebound_private.match_members where room_id=rid and not departed;
   if n>=5 then raise exception 'room_full'; end if;
   insert into lakebound_private.match_members(room_id,player_id,auth_id) values(rid,pid,auth.uid())
   on conflict(room_id,player_id) do update set departed=false,ready=false,loaded=false,auth_id=excluded.auth_id,seen_at=stamp;
  else
   select * into m from lakebound_private.match_members where room_id=rid and player_id=pid;
   if m.player_id is null or m.departed then raise exception 'not_a_member'; end if;
   update lakebound_private.match_members set auth_id=auth.uid(),seen_at=stamp where room_id=rid and player_id=pid;
   -- Lobby disconnects cannot strand the other testers forever. Active-round
   -- participants remain in the result and can reconnect until they explicitly leave.
   if r.phase='lobby' then
    delete from lakebound_private.match_members where room_id=rid and seen_at<stamp-interval '60 seconds';
   end if;
   if not exists(select 1 from lakebound_private.match_members where room_id=rid and player_id=r.host and not departed and seen_at>stamp-interval '20 seconds') then
    select player_id into rc from lakebound_private.match_members where room_id=rid and not departed and seen_at>stamp-interval '20 seconds' order by joined_at,player_id limit 1;
    if rc is not null then update lakebound_private.match_rooms set host=rc where id=rid; r.host:=rc; end if;
   end if;
   if op='ready' then
    if r.phase<>'lobby' or jsonb_typeof(payload->'ready') is distinct from 'boolean' then raise exception 'invalid_state'; end if;
    update lakebound_private.match_members set ready=(payload->>'ready')::boolean where room_id=rid and player_id=pid;
   elsif op='start' then
    if r.host<>pid or r.phase<>'lobby' then raise exception 'host_only'; end if;
    select count(*) into n from lakebound_private.match_members where room_id=rid and not departed;
    if n<2 or n>5 or exists(select 1 from lakebound_private.match_members where room_id=rid and not departed and (not ready or seen_at<stamp-interval '20 seconds')) then raise exception 'players_not_ready'; end if;
    update lakebound_private.match_rooms set phase='loading',loading_at=stamp where id=rid;
   elsif op='loaded' then
    if r.phase<>'loading' then raise exception 'invalid_state'; end if;
    update lakebound_private.match_members set loaded=true where room_id=rid and player_id=pid;
    if not exists(select 1 from lakebound_private.match_members where room_id=rid and not departed and not loaded) then
     update lakebound_private.match_rooms set phase='countdown',starts_at=stamp+interval '5 seconds',ends_at=stamp+interval '605 seconds' where id=rid;
    end if;
   elsif op='catch' then
    if payload->>'round_id' is distinct from r.round_id::text then raise exception 'wrong_round'; end if;
    cid:=payload->>'catch_id'; sid:=payload->>'species';
    if cid is null or cid !~ '^[a-f0-9]{32}$' or sid is null or jsonb_typeof(payload->'grams') is distinct from 'number'
      or (payload->>'grams')::numeric<>trunc((payload->>'grams')::numeric) or (payload->>'grams')::numeric not between 1 and 1000000000
      or not exists(select 1 from lakebound_private.species where id=sid) then raise exception 'invalid_catch'; end if;
    g:=(payload->>'grams')::integer;
    select * into prev from lakebound_private.match_catches where room_id=rid and player_id=pid and catch_id=cid;
    if found then
     if prev.grams<>g or prev.species_id<>sid then raise exception 'conflicting_catch'; end if;
    else
     if r.phase<>'running' or stamp<r.starts_at or stamp>=r.ends_at then raise exception 'outside_match'; end if;
     if (select count(*) from lakebound_private.match_catches where room_id=rid and player_id=pid)>=200 then raise exception 'catch_limit'; end if;
     insert into lakebound_private.match_catches(room_id,player_id,catch_id,species_id,grams) values(rid,pid,cid,sid,g);
    end if;
   elsif op='rematch' then
    if r.host<>pid or r.phase not in ('finished','cancelled') then raise exception 'host_only'; end if;
    delete from lakebound_private.match_catches where room_id=rid;
    delete from lakebound_private.match_members where room_id=rid and departed;
    update lakebound_private.match_members set ready=false,loaded=false where room_id=rid;
    update lakebound_private.match_rooms set phase='lobby',seed=floor(random()*2147483647),round_id=gen_random_uuid(),created_at=stamp,starts_at=null,ends_at=null,loading_at=null where id=rid;
   elsif op='leave' then
    update lakebound_private.match_members set departed=true,ready=false where room_id=rid and player_id=pid;
    if r.phase in ('loading','countdown') then
     update lakebound_private.match_rooms set phase='cancelled' where id=rid;
    end if;
    if r.host=pid then
      select player_id into rc from lakebound_private.match_members where room_id=rid and not departed order by joined_at,player_id limit 1;
      if rc is null then update lakebound_private.match_rooms set phase='cancelled' where id=rid;
      else update lakebound_private.match_rooms set host=rc where id=rid; end if;
    end if;
    if r.phase='lobby' then delete from lakebound_private.match_members where room_id=rid and player_id=pid; end if;
   elsif op<>'state' then raise exception 'invalid_operation';
   end if;
  end if;
 end if;
 return lakebound_private.match_snapshot(rid);
exception when raise_exception then return jsonb_build_object('error',sqlerrm);
 when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation then return jsonb_build_object('error','invalid_payload');
end $$;
revoke all on function public.lakebound_matches(jsonb) from public,anon;
grant execute on function public.lakebound_matches(jsonb) to authenticated;
commit;
