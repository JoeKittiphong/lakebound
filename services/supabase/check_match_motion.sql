-- Owner-only acceptance check; all temporary fixtures and reservations roll back.
begin;
do $smoke$
declare a jsonb; b jsonb; r jsonb; result jsonb; one uuid:=gen_random_uuid();two uuid:=gen_random_uuid(); used bigint; after_used bigint;
begin
 if not exists(select 1 from lakebound_private.match_limits where max_rooms=1 and max_players=5) then raise exception 'wrong_motion_limits'; end if;
 select coalesce(sum(reserved),0) into used from lakebound_private.match_budget;
 perform set_config('request.jwt.claims','{"app_metadata":{"provider":"google"}}',true);
 perform set_config('request.jwt.claim.sub',one::text,true);
 a:=public.lakebound_account('{}')->'identity';a:=a||jsonb_build_object('player_id',a->>'id','player_name',a->>'name');
 r:=public.lakebound_matches(a||jsonb_build_object('op','create','map','river','duration',180));
 if r ? 'error' or (r->>'pose_interval')::numeric is distinct from 0.334 then raise exception 'fast_room_create_failed: %',r; end if;
 select coalesce(sum(reserved),0) into after_used from lakebound_private.match_budget;
 if after_used-used<>32400 then raise exception 'incorrect_motion_reservation'; end if;
 perform set_config('request.jwt.claim.sub',two::text,true);
 b:=public.lakebound_account('{}')->'identity';b:=b||jsonb_build_object('player_id',b->>'id','player_name',b->>'name');
 result:=public.lakebound_matches(b||jsonb_build_object('op','create','map','river'));
 if result->>'error' is distinct from 'capacity_full' then raise exception 'second_room_was_not_blocked'; end if;
 result:=public.lakebound_matches(b||jsonb_build_object('op','join','code',r->>'code'));
 if result->>'id' is distinct from r->>'id' then raise exception 'same_room_join_failed'; end if;
 update lakebound_private.match_rooms set phase='finished',motion_interval=2.0 where id=(r->>'id')::uuid;
 perform set_config('request.jwt.claim.sub',one::text,true);
 result:=public.lakebound_matches(a||jsonb_build_object('op','rematch','room_id',r->>'id'));
 if result ? 'error' or (result->>'pose_interval')::numeric is distinct from 0.334 then raise exception 'rematch_upgrade_failed'; end if;
 select coalesce(sum(reserved),0) into after_used from lakebound_private.match_budget;
 if after_used-used<>64800 then raise exception 'incorrect_rematch_reservation'; end if;
end $smoke$;
rollback;
select 'fast_motion_smoke_passed' as result;
