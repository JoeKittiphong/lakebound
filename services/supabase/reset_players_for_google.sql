-- Explicit owner-only reset after migrations 003 through 006. Run only after
-- reviewing production counts and approval. No fish catalog/config deletion.
begin;
do $$ begin
 if to_regclass('lakebound_private.accounts') is null or to_regprocedure('lakebound_private.lakebound_rankings(jsonb)') is null then
  raise exception 'Install Google account migrations first';
 end if;
 if exists(select 1 from lakebound_private.accounts) or exists(select 1 from lakebound_private.match_rooms) then
  raise exception 'New account or match data exists: stop and review instead of resetting';
 end if;
 if to_regclass('lakebound_private.reset_20261102_players') is not null then
  raise exception 'Reset backup already exists: refusing to reset a second time';
 end if;
end $$;
lock table lakebound_private.players,lakebound_private.scores,lakebound_private.accounts,lakebound_private.match_rooms in access exclusive mode;
-- Already executed on production. Do not run again.
-- Reviewed production snapshot: 18 identities / 412 best records. The local
-- disposable test explicitly sets these two GUCs to its fixture counts.
do $$ declare
 expected_players bigint:=coalesce(nullif(current_setting('lakebound.reset_expected_players',true),''),'18')::bigint;
 expected_scores bigint:=coalesce(nullif(current_setting('lakebound.reset_expected_scores',true),''),'412')::bigint;
begin
 if (select count(*) from lakebound_private.players)<>expected_players
 or (select count(*) from lakebound_private.scores)<>expected_scores
 or exists(select 1 from lakebound_private.accounts) or exists(select 1 from lakebound_private.match_rooms) then
  raise exception 'Data changed since reset review: stop and re-check counts';
 end if;
end $$;
update lakebound_private.control set writes_enabled=false where singleton;
create table lakebound_private.reset_20261102_players as table lakebound_private.players;
create table lakebound_private.reset_20261102_scores as table lakebound_private.scores;
alter table lakebound_private.reset_20261102_players enable row level security;
alter table lakebound_private.reset_20261102_scores enable row level security;
revoke all on lakebound_private.reset_20261102_players,lakebound_private.reset_20261102_scores from public,anon,authenticated;
delete from lakebound_private.scores;
delete from lakebound_private.players;
update lakebound_private.control set writes_enabled=true where singleton;
commit;
