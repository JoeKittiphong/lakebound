begin;
create table lakebound_private.match_fish (
 room_id uuid not null references lakebound_private.match_rooms,
 round_id uuid not null, fish_id integer not null check(fish_id between 1 and 100000),
 player_id text not null references lakebound_private.players,
 claim_id uuid not null default gen_random_uuid(), expires_at timestamptz not null,
 species text not null references lakebound_private.species, grams integer not null check(grams between 1 and 1000000000),
 landed boolean not null default false, catch_id text,
 primary key(room_id,round_id,fish_id)
);
alter table lakebound_private.match_fish enable row level security;
revoke all on lakebound_private.match_fish from public,anon,authenticated;
-- Mark identifiable pre-fix catches as consumed, without rewriting past scores.
with possible as materialized (
 select r.id,r.round_id,i fish_id,md5(r.round_id::text||':'||i::text) catch_id
 from lakebound_private.match_rooms r cross join generate_series(1,10000) i
 where exists(select 1 from lakebound_private.match_catches c where c.room_id=r.id)
), previous as (
 select distinct on(p.id,p.round_id,p.fish_id) p.*,c.player_id,c.species_id,c.grams
 from possible p join lakebound_private.match_catches c on c.room_id=p.id and c.catch_id=p.catch_id
 order by p.id,p.round_id,p.fish_id,c.received_at,c.player_id
)
insert into lakebound_private.match_fish(room_id,round_id,fish_id,player_id,expires_at,species,grams,landed,catch_id)
 select id,round_id,fish_id,player_id,clock_timestamp(),species_id,grams,true,catch_id from previous;
-- Compact arrays keep snapshots bounded even after many catches.
do $patch$
declare d text; marker text:=$s$'members',coalesce$s$;
begin
 d:=pg_get_functiondef('lakebound_private.match_snapshot(uuid)'::regprocedure);
 if strpos(d,marker)=0 then raise exception 'unexpected_fish_snapshot'; end if;
 d:=replace(d,marker,$s$'fish_claims',coalesce((select jsonb_agg(jsonb_build_array(f.fish_id,f.player_id,f.claim_id,extract(epoch from f.expires_at),f.species,f.grams) order by f.fish_id) from lakebound_private.match_fish f where f.room_id=r.id and f.round_id=r.round_id and not f.landed and f.expires_at>clock_timestamp()),'[]'::jsonb),
 'consumed_fish',coalesce((select jsonb_agg(f.fish_id order by f.fish_id) from lakebound_private.match_fish f where f.room_id=r.id and f.round_id=r.round_id and f.landed),'[]'::jsonb),
 'members',coalesce$s$);
 execute d;
end $patch$;
alter function public.lakebound_matches(jsonb) rename to match_admission_v2;
alter function public.match_admission_v2(jsonb) set schema lakebound_private;
revoke all on function lakebound_private.match_admission_v2(jsonb) from public,anon,authenticated;
create function public.lakebound_matches(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' set lock_timeout='2s' as $fish$
declare op text:=payload->>'op'; pid text:=payload->>'player_id'; rid uuid; round uuid; fid integer;
 stamp timestamptz; snap jsonb; result jsonb; f lakebound_private.match_fish%rowtype;
 sid text; weight integer; cid text; prior lakebound_private.match_catches%rowtype;
begin
 if op not in ('claim_fish','renew_fish','release_fish','catch') then
  result:=lakebound_private.match_admission_v2(payload);
  if op='leave' and not(result ? 'error') then
   update lakebound_private.match_fish set expires_at=clock_timestamp() where room_id=(result->>'id')::uuid and player_id=pid and not landed;
   return lakebound_private.match_snapshot((result->>'id')::uuid);
  end if;
  return result;
 end if;
 -- The existing gateway checks Google identity, token, membership, admission,
 -- request rate and lease before this transaction touches a fish.
 snap:=lakebound_private.match_admission_v2(payload||jsonb_build_object('op','state'));
 if snap ? 'error' then return snap; end if;
 rid:=(snap->>'id')::uuid; round:=(snap->>'round_id')::uuid; stamp:=clock_timestamp();
 if payload->>'round_id' is distinct from round::text then return jsonb_build_object('error','wrong_round'); end if;
 if jsonb_typeof(payload->'fish_id') is distinct from 'number' or (payload->>'fish_id')::numeric not between 1 and 100000
  or (payload->>'fish_id')::numeric<>trunc((payload->>'fish_id')::numeric) then return jsonb_build_object('error','fish_claim_required'); end if;
 fid:=((payload->>'fish_id')::numeric)::integer;
 select * into f from lakebound_private.match_fish where room_id=rid and round_id=round and fish_id=fid for update;
 if op='release_fish' then
  if f.player_id=pid and f.claim_id::text=payload->>'claim_id' and not f.landed then
   update lakebound_private.match_fish set expires_at=stamp where room_id=rid and round_id=round and fish_id=fid;
  end if;
  return lakebound_private.match_snapshot(rid);
 end if;
 if op='catch' then
  sid:=payload->>'species'; cid:=payload->>'catch_id';
  if cid is null or cid !~ '^[a-f0-9]{32}$' or jsonb_typeof(payload->'grams') is distinct from 'number'
   or (payload->>'grams')::numeric not between 1 and 1000000000 or (payload->>'grams')::numeric<>trunc((payload->>'grams')::numeric)
   or not exists(select 1 from lakebound_private.species where id=sid) then return jsonb_build_object('error','invalid_catch'); end if;
  weight:=((payload->>'grams')::numeric)::integer;
  if f.landed and f.player_id=pid and f.claim_id::text=payload->>'claim_id' and f.catch_id=cid then
   if f.species<>sid or f.grams<>weight then return jsonb_build_object('error','conflicting_catch'); end if;
   return lakebound_private.match_snapshot(rid);
  end if;
 end if;
 if snap->>'phase'<>'running' or stamp<to_timestamp((snap->>'starts_at')::double precision)
  or stamp>=to_timestamp((snap->>'ends_at')::double precision) then return jsonb_build_object('error','outside_match'); end if;
 if op='claim_fish' then
  sid:=payload->>'species';
  if jsonb_typeof(payload->'grams') is distinct from 'number' or (payload->>'grams')::numeric not between 1 and 1000000000
   or (payload->>'grams')::numeric<>trunc((payload->>'grams')::numeric)
   or not exists(select 1 from lakebound_private.match_species where map_id=snap->>'map' and species_id=sid) then return jsonb_build_object('error','invalid_catch'); end if;
  weight:=((payload->>'grams')::numeric)::integer;
  if f.landed then return jsonb_build_object('error','fish_already_caught'); end if;
  if f.expires_at>stamp and f.player_id<>pid then return jsonb_build_object('error','fish_busy'); end if;
  if f.fish_id is not null and (f.species<>sid or f.grams<>weight) then return jsonb_build_object('error','fish_metadata_mismatch'); end if;
  if exists(select 1 from lakebound_private.match_fish where room_id=rid and round_id=round and player_id=pid
   and not landed and expires_at>stamp and fish_id<>fid) then return jsonb_build_object('error','already_hooked'); end if;
  if f.player_id=pid and f.expires_at>stamp then return lakebound_private.match_snapshot(rid); end if;
  insert into lakebound_private.match_fish(room_id,round_id,fish_id,player_id,expires_at,species,grams)
   values(rid,round,fid,pid,stamp+interval '90 seconds',sid,weight)
   on conflict(room_id,round_id,fish_id) do update set player_id=excluded.player_id,claim_id=gen_random_uuid(),expires_at=excluded.expires_at;
  return lakebound_private.match_snapshot(rid);
 end if;
 if f.landed then return jsonb_build_object('error','fish_already_caught'); end if;
 if f.player_id is distinct from pid or f.claim_id::text is distinct from payload->>'claim_id' or f.expires_at<=stamp
  then return jsonb_build_object('error','fish_claim_expired'); end if;
 if op='renew_fish' then
  update lakebound_private.match_fish set expires_at=stamp+interval '90 seconds' where room_id=rid and round_id=round and fish_id=fid;
  return lakebound_private.match_snapshot(rid);
 end if;
 if f.species<>sid or f.grams<>weight then return jsonb_build_object('error','conflicting_catch'); end if;
 select * into prior from lakebound_private.match_catches where room_id=rid and player_id=pid and catch_id=cid;
 if found then return jsonb_build_object('error','conflicting_catch'); end if;
 result:=lakebound_private.lakebound_matches(payload||jsonb_build_object('grams',weight));
 if result ? 'error' then return result; end if;
 update lakebound_private.match_fish set landed=true,catch_id=cid where room_id=rid and round_id=round and fish_id=fid;
 return lakebound_private.match_snapshot(rid);
exception when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('error','invalid_payload');
 when lock_not_available or deadlock_detected then return jsonb_build_object('error','busy_retry');
end $fish$;
revoke all on function public.lakebound_matches(jsonb) from public,anon;
grant execute on function public.lakebound_matches(jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
