-- Owner-only acceptance smoke. All temporary players/rooms are rolled back.
begin;
do $smoke$
declare first_identity jsonb; second_identity jsonb; room jsonb; joined jsonb;
begin
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 perform set_config('request.jwt.claims','{"app_metadata":{"provider":"google"}}',true);
 first_identity:=public.lakebound_account('{}')->'identity';
 room:=public.lakebound_matches(first_identity||jsonb_build_object('op','create','map','lotus_marsh','player_id',first_identity->>'id','player_name',first_identity->>'name'));
 if room->>'code' !~ '^[0-9]{5}$' or room ? 'error' then raise exception 'five_digit_create_failed'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 second_identity:=public.lakebound_account('{}')->'identity';
 joined:=public.lakebound_matches(second_identity||jsonb_build_object('op','join','code',room->>'code','player_id',second_identity->>'id','player_name',second_identity->>'name'));
 if joined->>'id' is distinct from room->>'id' or jsonb_array_length(joined->'members')<>2 then raise exception 'five_digit_join_failed'; end if;
end $smoke$;
rollback;
select 'five_digit_create_join_rollback_passed' as result;
