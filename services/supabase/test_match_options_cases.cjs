const {spawn}=require('node:child_process'),path=require('node:path');
module.exports=async function({sql,q,rpc,people,uid,check}){
 const clean=()=>sql("truncate lakebound_private.match_leases,lakebound_private.match_requests,lakebound_private.match_budget;update lakebound_private.match_rooms set phase='cancelled';update lakebound_private.match_limits set max_rooms=4,max_players=20,monthly_events=1500000,accepts_new=true;");
 const forceRunning=r=>sql(`update lakebound_private.match_rooms set phase='running',starts_at=clock_timestamp()-interval '1 second',ends_at=clock_timestamp()+make_interval(secs=>duration) where id='${r.id}';`);
 const catchFish=(i,r,n,grams,species='tilapia')=>rpc(i,'catch',{room_id:r.id,round_id:r.round_id,catch_id:n.toString(16).padStart(32,'0'),grams,species});
 // PostgreSQL's fixture helper resets the per-user window for functional tests;
 // the explicit burst test below uses the raw gateway and does not reset it.
 const parallel=(ops)=>Promise.all(ops.map(({i,op,data={}})=>new Promise((resolve,reject)=>{
  const bin=process.env.PG_BIN||'C:/Program Files/PostgreSQL/18/bin';
  const child=spawn(path.join(bin,'psql.exe'),['-h','127.0.0.1','-p',process.env.LAKEBOUND_TEST_PG_PORT,'-U','postgres','-X','-A','-t','-v','ON_ERROR_STOP=1'],{windowsHide:true});
  let out='',err='';child.stdout.on('data',b=>out+=b);child.stderr.on('data',b=>err+=b);child.on('error',reject);
  child.on('exit',code=>code?reject(Error(err)):resolve(JSON.parse(out.trim().split('\n').at(-1))));
  child.stdin.end(`set role authenticated;set request.jwt.claim.sub='${uid(i)}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';select public.lakebound_matches(${q({...people[i],op,...data})});`);
 })));
 clean();check(rpc(0,'quick_join').error==='no_open_rooms','quick join does not invent a room when none are open');
 for(const duration of [180,300,600,900,1200]){
  clean();let r=rpc(0,'create',{map:'lotus_marsh',duration,rule:'total_weight'});
  check(r.duration===duration&&r.rule==='total_weight','room accepts duration '+duration);
  rpc(1,'quick_join');for(const i of [0,1])rpc(i,'ready',{room_id:r.id,ready:true});rpc(0,'start',{room_id:r.id});
  rpc(0,'loaded',{room_id:r.id});r=rpc(1,'loaded',{room_id:r.id});
  check(r.phase==='countdown'&&r.ends_at-r.starts_at===duration,'database clock honors duration '+duration);
 }
 clean();
 for(const duration of [0,179,240,180.5,'180',null])check(rpc(0,'create',{map:'river',duration}).error==='invalid_duration','reject invalid duration '+duration);
 check(rpc(0,'create',{map:'river',rule:'legacy_top3'}).error==='invalid_rule','old scoring cannot be selected for new rooms');
 check(rpc(0,'create',{map:'lotus_marsh',rule:'species_total',target_species:'bluefin_tuna'}).error==='invalid_target_species','target must live in selected map');
 check(rpc(0,'create',{map:'lotus_marsh',rule:'species_total'}).error==='invalid_target_species','target mode requires species');
 check(rpc(0,'create',{map:'lotus_marsh',rule:'total_weight',target_species:'tilapia'}).error==='invalid_target_species','all-species mode cannot hide a target filter');
 for(const rule of ['species_total','total_weight','biggest_fish']){
  clean();let r=rpc(0,'create',{map:'lotus_marsh',duration:300,rule,...(rule==='species_total'?{target_species:'tilapia'}:{})});
  check(rpc(1,'quick_join').id===r.id,'quick join uses creator settings for '+rule);
  check(rpc(1,'quick_join').members.length===2,'quick join retry resumes same membership');
  forceRunning(r);
  if(rule==='species_total'){
   catchFish(0,r,1,1000);catchFish(0,r,2,2000);catchFish(0,r,3,9000,'snakehead');catchFish(1,r,4,3000);
   r=rpc(0,'state',{room_id:r.id});check(r.members[0].grams===3000&&r.members.filter(m=>m.rank===1).length===2,'species total filters other fish and ties only on eligible weight');
  }else if(rule==='total_weight'){
   for(const [j,g]of [1000,2000,3000,4000].entries())catchFish(0,r,j+1,g,j===3?'snakehead':'tilapia');
   catchFish(1,r,5,9000);r=rpc(0,'state',{room_id:r.id});check(r.members[0].grams===10000,'total weight counts every fish beyond top three');
   catchFish(1,r,6,1000);r=rpc(0,'state',{room_id:r.id});check(r.members.filter(m=>m.rank===1).length===2,'equal total weight shares rank despite different biggest fish');
  }else{
   catchFish(0,r,1,1000);catchFish(0,r,2,6000);catchFish(0,r,3,2000);catchFish(1,r,4,7000,'snakehead');
   r=rpc(0,'state',{room_id:r.id});check(r.members[0].id===people[1].player_id&&r.members[0].grams===7000,'biggest-fish mode ignores sum and allows any species');
   catchFish(0,r,5,7000);r=rpc(0,'state',{room_id:r.id});check(r.members.filter(m=>m.rank===1).length===2,'equal biggest fish shares rank');
  }
  sql(`update lakebound_private.match_rooms set phase='finished' where id='${r.id}';`);
  const again=rpc(0,'rematch',{room_id:r.id});check(again.rule===rule&&again.duration===300&&again.target_species===(rule==='species_total'?'tilapia':''),'rematch retains immutable room rules '+rule);
 }
 clean();let r=rpc(0,'create',{map:'river'});
 sql(`update lakebound_private.match_members set seen_at=clock_timestamp()-interval '30 seconds' where room_id='${r.id}';`);
 check(rpc(1,'quick_join').error==='no_open_rooms','quick join skips disconnected hosts');
 clean();r=rpc(0,'create',{map:'river'});sql(`update lakebound_private.match_rooms set phase='running',starts_at=clock_timestamp(),ends_at=clock_timestamp()+interval '1 minute' where id='${r.id}';`);
 check(rpc(1,'quick_join').error==='no_open_rooms','quick join skips running matches');
 clean();r=rpc(0,'create',{map:'river'});const joins=await parallel(Array.from({length:6},(_,j)=>({i:j+1,op:'quick_join'})));
 check(joins.filter(x=>!x.error).length===4&&joins.filter(x=>x.error==='no_open_rooms').length===2,'simultaneous quick joins fill at most five seats');
 clean();sql('update lakebound_private.match_limits set max_players=2;');r=rpc(0,'create',{map:'river'});rpc(1,'join',{code:r.code});
 check(rpc(2,'join',{code:r.code}).error==='capacity_full','manual join respects global player ceiling');
 check(rpc(2,'quick_join').error==='capacity_full','quick join respects global player ceiling');
 check(rpc(2,'create',{map:'river'}).error==='capacity_full','create respects global player ceiling');
 sql(`update lakebound_private.match_leases set expires_at=clock_timestamp()-interval '1 second' where auth_id='${uid(1)}';`);
 check(rpc(2,'quick_join').id===r.id,'expired lease frees global player slot');
 check(rpc(1,'state',{room_id:r.id}).error==='capacity_full','expired client must reacquire capacity before reconnect');
 clean();sql('update lakebound_private.match_limits set max_rooms=1;');r=rpc(0,'create',{map:'river'});
 check(rpc(1,'create',{map:'lotus_marsh'}).error==='capacity_full','global room ceiling rejects another room');
 check(rpc(1,'quick_join').id===r.id,'existing room can fill while room ceiling reached');
 sql(`update lakebound_private.match_rooms set phase='finished' where id='${r.id}';`);const other=rpc(2,'create',{map:'river'});
 check(!!other.id&&rpc(0,'rematch',{room_id:r.id}).error==='capacity_full','rematch must reacquire global room capacity');
 clean();sql('update lakebound_private.match_limits set monthly_events=32400;');
 const budgetRace=await parallel([{i:0,op:'create',data:{map:'river',duration:180}},{i:1,op:'create',data:{map:'river',duration:180}}]);
 check(budgetRace.filter(x=>x.id).length===1&&budgetRace.filter(x=>x.error==='monthly_capacity_reached').length===1,'concurrent room creation cannot overspend monthly reservation');
 check(sql('select sum(reserved) from lakebound_private.match_budget;')==='32400','monthly budget reserves full round once');
 const winner=budgetRace.findIndex(x=>x.id);r=budgetRace[winner];
 check(rpc(winner,'create',{map:'river',duration:180}).id===r.id&&sql('select sum(reserved) from lakebound_private.match_budget;')==='32400','create retry does not reserve monthly budget twice');
 check(rpc(winner,'state',{room_id:r.id}).id===r.id,'monthly cap lets already reserved games continue');
 check(rpc(2,'quick_join').id===r.id,'joining reserved room needs no new monthly budget');
 sql("truncate lakebound_private.match_requests;");
 sql(`do $$ declare result jsonb; i integer; begin perform set_config('request.jwt.claim.sub','${uid(winner)}',true);perform set_config('request.jwt.claims','{"app_metadata":{"provider":"google"}}',true);for i in 1..7 loop result:=public.lakebound_matches(${q({...people[winner],op:'state',room_id:r.id})});end loop;if result->>'error' is distinct from 'rate_limited' then raise exception 'burst was not throttled';end if;end $$;`);
 check(true,'server rate limit blocks seventh rapid request');
 check(sql("select has_table_privilege('authenticated','lakebound_private.match_limits','update');")==='f','client cannot raise its own capacity limits');
 clean();sql('update lakebound_private.match_limits set accepts_new=false;');
 check(rpc(0,'create',{map:'river'}).error==='capacity_full','owner can pause new admissions');
 clean();sql("update lakebound_private.match_limits set monthly_events=32400;insert into lakebound_private.match_budget values((clock_timestamp() at time zone 'UTC')::date-31,32400);");
 check(rpc(0,'create',{map:'river',duration:180}).error==='monthly_capacity_reached','rolling budget includes previous month instead of early calendar reset');
 sql("update lakebound_private.match_budget set month=(clock_timestamp() at time zone 'UTC')::date-33;");
 check(!!rpc(0,'create',{map:'river',duration:180}).id,'reservation capacity returns after conservative rolling window');
 clean();
 const smoke=require('node:fs').readFileSync(path.join(__dirname,'check_match_options.sql'),'utf8');
 check(sql(smoke).includes('quick_rules_smoke_passed'),'owner acceptance smoke exercises quick join and all three rules then rolls fixtures back');
};

