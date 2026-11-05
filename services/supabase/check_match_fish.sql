-- Owner-only smoke; every temporary account, room, fish and score rolls back.
begin;
do $smoke$
declare a jsonb; b jsonb; room jsonb; result jsonb; packet jsonb; one uuid:=gen_random_uuid();two uuid:=gen_random_uuid();nonce text;
begin
 perform set_config('request.jwt.claims','{"app_metadata":{"provider":"google"}}',true);
 perform set_config('request.jwt.claim.sub',one::text,true);
 a:=public.lakebound_account('{}')->'identity';a:=a||jsonb_build_object('player_id',a->>'id','player_name',a->>'name');
 room:=public.lakebound_matches(a||jsonb_build_object('op','create','map','lotus_marsh','duration',180,'rule','total_weight'));
 if room ? 'error' then raise exception 'create failed: %',room; end if;
 perform set_config('request.jwt.claim.sub',two::text,true);
 b:=public.lakebound_account('{}')->'identity';b:=b||jsonb_build_object('player_id',b->>'id','player_name',b->>'name');
 result:=public.lakebound_matches(b||jsonb_build_object('op','join','code',room->>'code'));
 if result->>'id' is distinct from room->>'id' then raise exception 'join failed'; end if;
 update lakebound_private.match_rooms set phase='running',starts_at=clock_timestamp()-interval '1 second',ends_at=clock_timestamp()+interval '3 minutes' where id=(room->>'id')::uuid;
 packet:=jsonb_build_object('op','claim_fish','room_id',room->>'id','round_id',room->>'round_id','fish_id',1,'species','tilapia','grams',1000);
 perform set_config('request.jwt.claim.sub',one::text,true);
 result:=public.lakebound_matches(a||packet);
 select value->>2 into nonce from jsonb_array_elements(result->'fish_claims') where (value->>0)::integer=1;
 if nonce is null then raise exception 'claim missing'; end if;
 perform set_config('request.jwt.claim.sub',two::text,true);
 result:=public.lakebound_matches(b||packet);
 if result->>'error' is distinct from 'fish_busy' then raise exception 'duplicate bite allowed'; end if;
 packet:=packet||jsonb_build_object('op','catch','claim_id',nonce,'catch_id',repeat('a',32));
 perform set_config('request.jwt.claim.sub',one::text,true);
 result:=public.lakebound_matches(a||packet);
 if result ? 'error' then raise exception 'owner catch failed: %',result; end if;
 result:=public.lakebound_matches(a||packet);
 if (result->'members'->0->>'grams')::integer<>1000 or jsonb_array_length(result->'consumed_fish')<>1 then raise exception 'duplicate score or missing consumed fish'; end if;
 perform set_config('request.jwt.claim.sub',two::text,true);
 result:=public.lakebound_matches(b||packet);
 if result->>'error' is distinct from 'fish_already_caught' then raise exception 'duplicate credit allowed'; end if;
end $smoke$;
rollback;
select 'exclusive_fish_smoke_passed' as result;
