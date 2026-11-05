module.exports=function({sql,check,migration}){
 const body=migration.replace(/^begin;/,'').replace(/commit;\s*$/,'');
 const fixture=n=>`begin;update lakebound_private.control set writes_enabled=true;do $fixture$ declare a jsonb; r jsonb; i integer; begin for i in 1..${n} loop perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);perform set_config('request.jwt.claims','{"app_metadata":{"provider":"google"}}',true);a:=public.lakebound_account('{}')->'identity';a:=a||jsonb_build_object('player_id',a->>'id','player_name',a->>'name');r:=public.lakebound_matches(a||jsonb_build_object('op','create','map','river','duration',180));if r ? 'error' then raise exception 'fixture_failed';end if;end loop;end $fixture$;`;
 check(sql(fixture(1)+body+"select ((select sum(reserved) from lakebound_private.match_budget)=32400 and (select min(motion_interval) from lakebound_private.match_rooms)=0.334)::text;rollback;").includes('true'),'migration tops up existing leased round without deleting old reservations');
 let blocked=false;
 try{sql(fixture(2)+body+'rollback;');}catch(e){if(!String(e).includes('finish_extra_rooms_before_motion_upgrade'))throw e;blocked=true;}
 check(blocked,'migration refuses multiple live rooms atomically');
 blocked=false;
 try{sql(fixture(1)+'update lakebound_private.match_limits set monthly_events=5400;'+body+'rollback;');}catch(e){if(!String(e).includes('insufficient_motion_upgrade_budget'))throw e;blocked=true;}
 check(blocked,'migration refuses faster legacy round without enough budget');
};
