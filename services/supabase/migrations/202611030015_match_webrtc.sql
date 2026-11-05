begin;
create table lakebound_private.rtc_peers(room_id uuid references lakebound_private.match_rooms,round_id uuid,player_id text references lakebound_private.players,session_id text check(session_id~'^[a-f0-9]{32}$'),seen_at timestamptz not null,primary key(room_id,round_id,player_id));
create table lakebound_private.rtc_signals(id bigserial primary key,room_id uuid,round_id uuid,from_player text,to_player text,from_session text,to_session text,kind text,data jsonb,created_at timestamptz not null default clock_timestamp());
create index rtc_inbox on lakebound_private.rtc_signals(room_id,round_id,to_player,id);
create table lakebound_private.turn_credentials(auth_id uuid,room_id uuid references lakebound_private.match_rooms,round_id uuid,ticket uuid not null default gen_random_uuid(),ice jsonb,expires_at timestamptz,requested_at timestamptz not null default clock_timestamp(),attempts integer not null default 1,primary key(auth_id,room_id,round_id));
alter table lakebound_private.rtc_peers enable row level security;
alter table lakebound_private.rtc_signals enable row level security;
alter table lakebound_private.turn_credentials enable row level security;
revoke all on lakebound_private.rtc_peers,lakebound_private.rtc_signals,lakebound_private.turn_credentials from public,anon,authenticated;
create function public.lakebound_rtc(payload jsonb) returns jsonb language plpgsql volatile security definer set search_path='' set statement_timeout='8s' as $rtc$
declare snap jsonb; pid text:=payload->>'player_id'; rid uuid; round uuid; session text:=payload->>'session_id'; op text:=payload->>'op'; stamp timestamptz:=clock_timestamp(); item jsonb; peer lakebound_private.rtc_peers%rowtype; cursor_id bigint:=coalesce((payload->>'cursor')::bigint,0); inbox jsonb; roster jsonb;
begin
 if jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>49152 or session is null or session!~'^[a-f0-9]{32}$' or op not in ('open','poll','send','close') then return jsonb_build_object('error','invalid_rtc_payload');end if;
 snap:=public.lakebound_matches(jsonb_build_object('op','state','player_id',pid,'player_name',(select player_name from lakebound_private.players where player_id=pid),'token',payload->>'token','room_id',payload->>'room_id'));
 if snap ? 'error' then return snap;end if;
 if snap->>'round_id' is distinct from payload->>'round_id' then return jsonb_build_object('error','wrong_round');end if;
 rid:=(snap->>'id')::uuid;round:=(snap->>'round_id')::uuid;
 if snap->>'phase' not in ('lobby','loading','countdown','running') then return jsonb_build_object('error','outside_match');end if;
 delete from lakebound_private.rtc_signals where created_at<stamp-interval '90 seconds';
 delete from lakebound_private.rtc_peers where seen_at<stamp-interval '75 seconds';
 if op='open' then
  insert into lakebound_private.rtc_peers values(rid,round,pid,session,stamp) on conflict(room_id,round_id,player_id) do update set session_id=excluded.session_id,seen_at=excluded.seen_at;
 else
  select * into peer from lakebound_private.rtc_peers where room_id=rid and round_id=round and player_id=pid;
  if peer.session_id is distinct from session then return jsonb_build_object('error','stale_rtc_session');end if;
  update lakebound_private.rtc_peers set seen_at=stamp where room_id=rid and round_id=round and player_id=pid;
 end if;
 if op='close' then delete from lakebound_private.rtc_peers where room_id=rid and round_id=round and player_id=pid;return jsonb_build_object('ok',true);end if;
 if op='send' then
  if jsonb_typeof(payload->'items') is distinct from 'array' or jsonb_array_length(payload->'items')>16 then return jsonb_build_object('error','invalid_rtc_payload');end if;
  if (select count(*) from lakebound_private.rtc_signals where room_id=rid and round_id=round and from_player=pid)>256 then return jsonb_build_object('error','rtc_signal_limit');end if;
  for item in select value from jsonb_array_elements(payload->'items') loop
   select * into peer from lakebound_private.rtc_peers where room_id=rid and round_id=round and player_id=item->>'to';
   if peer.session_id is distinct from item->>'to_session' or peer.player_id=pid or peer.player_id is null then continue;end if;
   if item->>'kind' not in ('offer','answer','candidate') or item->>'kind' is null or octet_length((item->'data')::text)>18000 then return jsonb_build_object('error','invalid_rtc_payload');end if;
   if item->>'kind' in ('offer','answer') and (jsonb_typeof(item->'data') is distinct from 'string' or length(item->>'data')>16000) then return jsonb_build_object('error','invalid_rtc_payload');end if;
   if item->>'kind'='candidate' and (jsonb_typeof(item->'data') is distinct from 'object' or jsonb_typeof(item->'data'->'mid') is distinct from 'string' or jsonb_typeof(item->'data'->'index') is distinct from 'number' or jsonb_typeof(item->'data'->'candidate') is distinct from 'string' or length(item->'data'->>'candidate')>2048) then return jsonb_build_object('error','invalid_rtc_payload');end if;
   insert into lakebound_private.rtc_signals(room_id,round_id,from_player,to_player,from_session,to_session,kind,data) values(rid,round,pid,peer.player_id,session,peer.session_id,item->>'kind',item->'data');
  end loop;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('player_id',p.player_id,'session_id',p.session_id)),'[]'::jsonb) into roster from lakebound_private.rtc_peers p join lakebound_private.match_members m on m.room_id=p.room_id and m.player_id=p.player_id where p.room_id=rid and p.round_id=round and not m.departed and m.seen_at>stamp-interval '75 seconds';
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'from',s.from_player,'session',s.from_session,'kind',s.kind,'data',s.data) order by s.id),'[]'::jsonb) into inbox from (select * from lakebound_private.rtc_signals where room_id=rid and round_id=round and to_player=pid and to_session=session and id>cursor_id order by id limit 64) s;
 return jsonb_build_object('room_id',rid,'round_id',round,'peers',roster,'signals',inbox);
exception when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('error','invalid_rtc_payload');end $rtc$;
revoke all on function public.lakebound_rtc(jsonb) from public,anon;
grant execute on function public.lakebound_rtc(jsonb) to authenticated;
-- Only the Edge Function's existing server role can reserve/cache TURN credentials.
create function public.lakebound_turn_cache(payload jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $cache$
declare uid uuid:=(payload->>'auth_id')::uuid; rid uuid:=(payload->>'room_id')::uuid; round uuid:=(payload->>'round_id')::uuid; c lakebound_private.turn_credentials%rowtype; stamp timestamptz:=clock_timestamp();
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then return jsonb_build_object('error','forbidden');end if;
 perform pg_advisory_xact_lock(741153);
 select * into c from lakebound_private.turn_credentials where auth_id=uid and room_id=rid and round_id=round for update;
 if payload->>'op'='commit' then
  if c.ticket::text is distinct from payload->>'ticket' or c.ice is not null or jsonb_typeof(payload->'iceServers') is distinct from 'array' then return jsonb_build_object('error','invalid_ticket');end if;
  update lakebound_private.turn_credentials set ice=payload->'iceServers',expires_at=stamp+interval '3300 seconds' where auth_id=uid and room_id=rid and round_id=round;
  return jsonb_build_object('iceServers',payload->'iceServers','expiresIn',3300);
 end if;
 if payload->>'op'<>'reserve' then return jsonb_build_object('error','invalid_op');end if;
 if c.ice is not null and c.expires_at>stamp+interval '120 seconds' then return jsonb_build_object('iceServers',c.ice,'expiresIn',floor(extract(epoch from c.expires_at-stamp)));end if;
 if c.auth_id is not null and (c.requested_at>stamp-interval '60 seconds' or c.attempts>=3) then return jsonb_build_object('error','turn_rate_limited');end if;
 if (select coalesce(sum(attempts),0) from lakebound_private.turn_credentials where requested_at>=date_trunc('day',stamp))>=200 then return jsonb_build_object('error','turn_daily_limit');end if;
 insert into lakebound_private.turn_credentials(auth_id,room_id,round_id) values(uid,rid,round) on conflict(auth_id,room_id,round_id) do update set ticket=gen_random_uuid(),ice=null,expires_at=null,requested_at=stamp,attempts=turn_credentials.attempts+1 returning * into c;
 return jsonb_build_object('ticket',c.ticket);
end $cache$;
revoke all on function public.lakebound_turn_cache(jsonb) from public,anon,authenticated;
grant execute on function public.lakebound_turn_cache(jsonb) to service_role;
notify pgrst,'reload schema';
commit;
