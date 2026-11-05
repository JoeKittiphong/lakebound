-- Lakebound guest rankings. Credentials and scores are never exposed as tables.
begin;
create schema if not exists lakebound_private;
revoke all on schema lakebound_private from public, anon, authenticated;
create table if not exists lakebound_private.species (id text primary key);
create table if not exists lakebound_private.players (
 player_id text primary key check (player_id ~ '^[a-f0-9]{32}$'),
 player_name text not null check (char_length(player_name) between 2 and 24 and player_name !~ '[[:cntrl:]<>\[\]]'),
 token_hash text not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists lakebound_private.scores (
 player_id text not null references lakebound_private.players,
 map_id text not null check (map_id in ('river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast')),
 species_id text not null references lakebound_private.species,
 catch_id text not null check (char_length(catch_id) between 1 and 128 and catch_id !~ '[[:cntrl:]]'),
 weight_g bigint not null check (weight_g between 1 and 1000000000),
 caught_at numeric not null check (caught_at >= 0),
 primary key (player_id,map_id,species_id)
);
create index if not exists scores_global_order on lakebound_private.scores (weight_g desc,caught_at,player_id,catch_id);
create index if not exists scores_map_order on lakebound_private.scores (map_id,weight_g desc,caught_at,player_id,catch_id);
create table if not exists lakebound_private.control (
 singleton boolean primary key default true check (singleton),
 writes_enabled boolean not null default false
);
insert into lakebound_private.control(singleton) values(true) on conflict do nothing;
alter table lakebound_private.players enable row level security;
alter table lakebound_private.scores enable row level security;
alter table lakebound_private.species enable row level security;
alter table lakebound_private.control enable row level security;
revoke all on all tables in schema lakebound_private from public, anon, authenticated;

create or replace function lakebound_private.board(q jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
 s text := q->>'scope'; n integer; rows_json jsonb; v text;
begin
 if jsonb_typeof(q) is distinct from 'object'
 or jsonb_typeof(q->'scope') is distinct from 'string'
 or s not in ('all','river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast')
 or jsonb_typeof(q->'limit') is distinct from 'number' or q->>'limit' not in ('10','50','100')
 or (q ? 'version' and (jsonb_typeof(q->'version') is distinct from 'string' or length(q->>'version') > 128))
 then raise exception using message='invalid_query', errcode='P0001'; end if;
 n := (q->>'limit')::integer;
 with best as (
  select distinct on (sc.player_id) sc.* from lakebound_private.scores sc
  where s='all' or sc.map_id=s
  order by sc.player_id,sc.weight_g desc,sc.caught_at,sc.catch_id,sc.map_id,sc.species_id
 ), top_rows as (
  select b.*,p.player_name from best b join lakebound_private.players p using(player_id)
  order by weight_g desc,caught_at,player_id,catch_id,map_id,species_id limit n
 )
 select coalesce(jsonb_agg(case when s='all'
  then jsonb_build_array(player_id,player_name,map_id,species_id,weight_g)
  else jsonb_build_array(player_id,player_name,species_id,weight_g) end
  order by weight_g desc,caught_at,player_id,catch_id,map_id,species_id),'[]'::jsonb)
 into rows_json from top_rows;
 v := md5(rows_json::text);
 if q->>'version'=v then return jsonb_build_object('version',v,'not_modified',true); end if;
 return jsonb_build_object('schema',3,'version',v,'rows',rows_json);
end $$;
revoke all on function lakebound_private.board(jsonb) from public,anon,authenticated;

create or replace function public.lakebound_rankings(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' set statement_timeout = '8s' as $$
declare
 pid text; secret text; name_value text; digest_value text; old_hash text;
 r jsonb; old_score lakebound_private.scores%rowtype;
 map_value text; species_value text; catch_value text; grams bigint; seconds numeric;
 result jsonb;
begin
 if payload is null or jsonb_typeof(payload) <> 'object' or octet_length(payload::text)>100000
 then raise exception using message='invalid_payload',errcode='P0001'; end if;
 -- A public read carries only a query, never guest credentials.
 if not (payload ? 'player_id' or payload ? 'token' or payload ? 'catches' or payload ? 'player_name') then
  return lakebound_private.board(payload->'query');
 end if;
 if not (select writes_enabled from lakebound_private.control where singleton)
 then return jsonb_build_object('error','migration_in_progress'); end if;
 pid := payload->>'player_id'; secret := payload->>'token';
 if jsonb_typeof(payload->'player_id') is distinct from 'string' or pid !~ '^[a-f0-9]{32}$'
 or jsonb_typeof(payload->'token') is distinct from 'string' or secret !~ '^[a-f0-9]{64}$'
 or jsonb_typeof(payload->'catches') is distinct from 'array' or jsonb_array_length(payload->'catches')>100
 then raise exception using message='invalid_payload',errcode='P0001'; end if;
 -- Validate the query before making any writes; exceptions roll back the batch.
 if payload ? 'query' then result := lakebound_private.board(payload->'query'); end if;
 if payload ? 'player_name' then
  name_value := btrim(payload->>'player_name');
  if jsonb_typeof(payload->'player_name') is distinct from 'string'
  or char_length(name_value) not between 2 and 24 or name_value ~ '[[:cntrl:]<>\[\]]'
  then raise exception using message='invalid_name',errcode='P0001'; end if;
 end if;
 -- Same SHA-256 of JSON.stringify(token), base64url with padding as Apps Script.
 digest_value := translate(encode(sha256(convert_to(to_json(secret)::text,'UTF8')),'base64'),'+/','-_');
 -- Serialize one guest, not the whole leaderboard. Handles concurrent registration.
 perform pg_advisory_xact_lock(hashtextextended(pid,0));
 select token_hash into old_hash from lakebound_private.players where player_id=pid for update;
 if found then
  if old_hash <> digest_value then raise exception using message='invalid_credentials',errcode='P0001'; end if;
  if name_value is not null then
   update lakebound_private.players set player_name=name_value,updated_at=now()
   where player_id=pid and player_name<>name_value;
  end if;
 else
  if name_value is null then raise exception using message='name_required',errcode='P0001'; end if;
  insert into lakebound_private.players(player_id,player_name,token_hash) values(pid,name_value,digest_value);
 end if;
 for r in select value from jsonb_array_elements(payload->'catches') loop
  if jsonb_typeof(r) <> 'array' or jsonb_array_length(r)<>5
  or jsonb_typeof(r->0) <> 'string' or jsonb_typeof(r->1) <> 'string'
  or jsonb_typeof(r->2) <> 'number' or jsonb_typeof(r->3) <> 'number' or jsonb_typeof(r->4) <> 'string'
  then raise exception using message='invalid_catch',errcode='P0001'; end if;
  map_value := r->>0; species_value := r->>1; catch_value := r->>4;
  if map_value not in ('river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast')
  or not exists(select 1 from lakebound_private.species where id=species_value)
  or (r->>2)::numeric <> trunc((r->>2)::numeric) or (r->>2)::numeric not between 1 and 1000000000
  or (r->>3)::numeric < 0 or (r->>3)::numeric > extract(epoch from now())+86400
  or char_length(catch_value) not between 1 and 128 or catch_value ~ '[[:cntrl:]]'
  then raise exception using message='invalid_catch',errcode='P0001'; end if;
  grams := (r->>2)::bigint; seconds := floor((r->>3)::numeric*1000)/1000;
  select * into old_score from lakebound_private.scores
  where player_id=pid and map_id=map_value and species_id=species_value;
  if found and old_score.catch_id=catch_value and (old_score.weight_g<>grams or old_score.caught_at<>seconds)
  then raise exception using message='conflicting_catch',errcode='P0001'; end if;
  insert into lakebound_private.scores as sc(player_id,map_id,species_id,catch_id,weight_g,caught_at)
  values(pid,map_value,species_value,catch_value,grams,seconds)
  on conflict(player_id,map_id,species_id) do update
  set catch_id=excluded.catch_id,weight_g=excluded.weight_g,caught_at=excluded.caught_at
  where excluded.weight_g>sc.weight_g or (excluded.weight_g=sc.weight_g and
   (excluded.caught_at,excluded.catch_id)<(sc.caught_at,sc.catch_id));
 end loop;
 if payload ? 'query' then return lakebound_private.board(payload->'query'); end if;
 return jsonb_build_object('ok',true);
exception
 when raise_exception then return jsonb_build_object('error',sqlerrm);
 when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation
 then return jsonb_build_object('error','invalid_payload');
end $$;
revoke all on function public.lakebound_rankings(jsonb) from public;
grant execute on function public.lakebound_rankings(jsonb) to anon,authenticated;
comment on function public.lakebound_rankings(jsonb) is 'Bounded public rankings and authenticated guest score sync. Scores remain client-reported/provisional.';
commit;
