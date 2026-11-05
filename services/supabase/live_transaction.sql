-- SQL Editor smoke test: real database/RPC and anon role, always ROLLBACK.
-- The fixture is never committed or visible to concurrent leaderboard readers.
begin;
do $$ begin
 if exists(select 1 from lakebound_private.players where player_id=repeat('f',32))
 then raise exception 'QA fixture ID already in use; choose another fixture'; end if;
end $$;
set local role anon;
do $$
declare
 p jsonb := jsonb_build_object('player_id',repeat('f',32),'token',repeat('d',64),
  'player_name','Supabase QA','catches',jsonb_build_array(jsonb_build_array('river','tilapia',1000,1700000000,'supabase-qa-rollback')));
 r jsonb;
begin
 r:=public.lakebound_rankings(p);
 if r->>'ok' is distinct from 'true' then raise exception 'Upload failed: %',r; end if;
 r:=public.lakebound_rankings(p);
 if r->>'ok' is distinct from 'true' then raise exception 'Idempotent retry failed: %',r; end if;
 r:=public.lakebound_rankings(p||jsonb_build_object('token',repeat('e',64)));
 if r->>'error' is distinct from 'invalid_credentials' then raise exception 'Wrong token accepted: %',r; end if;
 r:=public.lakebound_rankings(p||jsonb_build_object('catches',jsonb_build_array(jsonb_build_array('river','tilapia',2000,1700000000,'supabase-qa-rollback'))));
 if r->>'error' is distinct from 'conflicting_catch' then raise exception 'Catch conflict accepted: %',r; end if;
 raise notice 'PASS live anon upload, duplicate retry, wrong token and conflicting catch';
end $$;
rollback;
select (select count(*) from lakebound_private.players) as players,
 (select count(*) from lakebound_private.scores) as scores,
 (select count(*) from lakebound_private.species) as species,
 (select writes_enabled from lakebound_private.control where singleton) as writes_enabled,
 not exists(select 1 from lakebound_private.players where player_id=repeat('f',32)) as qa_fixture_absent;
