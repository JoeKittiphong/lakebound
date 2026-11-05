// Real PostgreSQL transactions/RLS in a disposable loopback cluster, no cloud writes.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync,spawn}=require('node:child_process'),assert=require('node:assert/strict');
const bin=process.env.PG_BIN||'C:/Program Files/PostgreSQL/18/bin';
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'lakebound-match-pg-'));
const port=String(56000+Math.floor(Math.random()*5000));
process.env.LAKEBOUND_TEST_PG_PORT=port;
function run(exe,args,input){const r=spawnSync(path.join(bin,exe+'.exe'),args,{input,encoding:'utf8',windowsHide:true,timeout:60000});if(r.status!==0)throw Error(r.error||r.stderr||r.stdout);return r.stdout;}
function sql(s){return run('psql',['-h','127.0.0.1','-p',port,'-U','postgres','-X','-A','-t','-v','ON_ERROR_STOP=1'],s).trim();}
const q=x=>"'"+JSON.stringify(x).replaceAll("'","''")+"'::jsonb";
const people=Array.from({length:7},(_,i)=>({player_id:(i+1).toString(16).repeat(32),token:(i+1).toString(16).repeat(64),player_name:'นักตกปลา '+i}));
const uid=i=>'00000000-0000-4000-8000-'+String(i+1).padStart(12,'0');
const testFishIds=new Map(),roomNextFish=new Map();
function rpc(i,op,data={}){
 if(op==='catch'&&!Object.hasOwn(data,'fish_id')){
  const key=data.room_id+':'+data.round_id+':'+data.catch_id;
  if(!testFishIds.has(key)){const next=(roomNextFish.get(data.room_id)||0)+1;roomNextFish.set(data.room_id,next);testFishIds.set(key,next);}
  const fish_id=testFishIds.get(key);
  let claim_id=sql(`select claim_id from lakebound_private.match_fish where room_id='${data.room_id}' and round_id='${data.round_id}' and fish_id=${fish_id};`);
  if(!claim_id){const claimed=rpc(i,'claim_fish',{...data,fish_id});claim_id=claimed.fish_claims?.find(c=>c[0]===fish_id)?.[2]||'';}
  data={...data,fish_id,claim_id};
 }
 return JSON.parse(sql(`update lakebound_private.match_requests set window_at=clock_timestamp()-interval '2 seconds' where auth_id='${uid(i)}';set role authenticated; set request.jwt.claim.sub='${uid(i)}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';select public.lakebound_matches(${q({...people[i],op,...data})});`).split('\n').at(-1));
}
function account(i,provider='google'){return JSON.parse(sql(`set role authenticated;set request.jwt.claim.sub='${uid(i)}';set request.jwt.claims='{"app_metadata":{"provider":"${provider}"}}';select public.lakebound_account('{}');`).split('\n').at(-1));}
function googleRank(p){return JSON.parse(sql(`set role authenticated;set request.jwt.claim.sub='${uid(0)}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';select public.lakebound_rankings(${q(p)});`).split('\n').at(-1));}
let checks=0;function check(ok,label){assert.ok(ok,label);console.log('PASS '+label);checks++;}
async function main(){try{
 run('initdb',['-D',dir,'-U','postgres','--auth=trust','--encoding=UTF8','--no-locale']);
 run('pg_ctl',['-D',dir,'-l',path.join(dir,'server.log'),'-o',`-p ${port} -h 127.0.0.1`,'-w','start']);
 sql('create role anon;create role authenticated;create role service_role;');sql(fs.readFileSync(path.join(__dirname,'test_platform.sql'),'utf8'));
 for(const f of fs.readdirSync(path.join(__dirname,'migrations')).sort()){
  if(f==='202611030016_match_capacity.sql')continue; // Historical upgrade regressions run before the capacity upgrade.
  if(f==='202611030014_match_motion.sql')require('./test_motion_upgrade.cjs')({sql,check,migration:fs.readFileSync(path.join(__dirname,'migrations',f),'utf8')});
  if(f==='202611020010_five_digit_rooms.sql')sql("do $$ declare d text; begin d:=pg_get_functiondef('lakebound_private.lakebound_matches(jsonb)'::regprocedure); d:=regexp_replace(d,E'--[^\\r\\n]*','','g'); d:=regexp_replace(d,'[[:space:]]+',' ','g'); execute d; end $$;");
  sql(fs.readFileSync(path.join(__dirname,'migrations',f),'utf8'));
 }
 sql('update lakebound_private.control set writes_enabled=true;');
 check(sql('select max_rooms||\':\'||max_players from lakebound_private.match_limits;')==='1:5','motion migration defaults to one five-player room');
 // Isolate historical engine error semantics from the tighter global gate.
 // The motion cases restore and exercise the actual production limits.
 sql('update lakebound_private.match_limits set max_rooms=4,max_players=20;');
 sql(`select lakebound_private.lakebound_rankings(${q({player_id:'f'.repeat(32),token:'e'.repeat(64),player_name:'Legacy reset QA',catches:[['river','tilapia',1000,1700000000,'legacy-qa']]})});`);
 sql("set lakebound.reset_expected_players='1';set lakebound.reset_expected_scores='1';"+fs.readFileSync(path.join(__dirname,'reset_players_for_google.sql'),'utf8'));
 check(sql('select count(*) from lakebound_private.players;')==='0'&&sql('select count(*) from lakebound_private.scores;')==='0','Google reset starts player and score tables empty');
 check(sql('select count(*) from lakebound_private.reset_20261102_players;')==='1','reset retains private rollback snapshot');
 let resetRefused=false;try{sql(fs.readFileSync(path.join(__dirname,'reset_players_for_google.sql'),'utf8'));}catch{resetRefused=true;}check(resetRefused,'reset cannot run a second time over new progress');
 check(account(0,'email').error==='google_login_required','non-Google account registration denied');
 for(let i=0;i<people.length;i++){const identity=account(i).identity;people[i]={player_id:identity.id,token:identity.token,player_name:identity.name};}
 check(account(0).identity.id===people[0].player_id,'Google account returns stable player identity');
 const chosenName='ชื่อที่เลือกเอง';
 check(googleRank({...people[0],player_name:chosenName,catches:[]}).ok===true,'Google account can choose a name before its first catch');
 const renamed=account(0).identity;
 check(renamed.name===chosenName&&renamed.id===people[0].player_id&&renamed.token===people[0].token,'chosen name persists on account reload without replacing identity');
 people[0].player_name=chosenName;
 check(new Set(people.map(p=>p.player_id)).size===people.length,'Google accounts have isolated identities');
 check(sql("select has_table_privilege('authenticated','lakebound_private.accounts','select');")==='f','account credentials never exposed as table');
 check(rpc(0,'create',{map:'river',player_id:people[1].player_id}).error==='account_mismatch','Google JWT cannot claim another player identity');
 const score={...people[0],catches:[['river','tilapia',1111,1700000000,'google-qa']]};
 check(googleRank(score).ok===true,'Google account can upload its own ranking');
 check(googleRank({...score,player_id:people[1].player_id}).error==='account_mismatch','Google account cannot upload another profile ranking');
 check(JSON.parse(sql(`set role anon;select public.lakebound_rankings(${q(score)});`).split('\n').at(-1)).error==='google_login_required','legacy guest builds cannot repopulate cleared scores');
 check(JSON.parse(sql(`set role anon;select public.lakebound_rankings(${q({query:{scope:'all',limit:10}})});`).split('\n').at(-1)).rows.length===1,'public rankings remain readable without login');
 const collisionCode=sql("select setseed(0.42);select lpad(floor(random()*100000)::integer::text,5,'0');").split('\n').at(-1);
 sql(`insert into lakebound_private.match_rooms(code,host,map_id,phase) values('${collisionCode}','${people[0].player_id}','river','cancelled');`);
 let r=JSON.parse(sql(`set role authenticated;set request.jwt.claim.sub='${uid(0)}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';select setseed(0.42);select public.lakebound_matches(${q({...people[0],op:'create',map:'lotus_marsh'})});`).split('\n').at(-1));
 check(r.schema===1&&r.members.length===1&&/^[0-9]{5}$/.test(r.code),'create authenticated private room with five decimal digits');
 check(r.code!==collisionCode,'code collision retries without failing room creation');
 sql(`update lakebound_private.match_rooms set rule='legacy_top3' where id='${r.id}';`);
 const preserved={id:r.id,round:r.round_id};
 sql(`update lakebound_private.match_rooms set code='OLDABC1234' where id='${r.id}';`);
 sql(fs.readFileSync(path.join(__dirname,'migrations','202611020010_five_digit_rooms.sql'),'utf8'));
 r=rpc(0,'state',{room_id:r.id});
 check(r.id===preserved.id&&r.round_id===preserved.round&&r.members.length===1&&/^[0-9]{5}$/.test(r.code),'migration recodes existing rooms while preserving round and membership');
 sql(`update lakebound_private.match_rooms set code='00001' where id='${r.id}';`);
 r=rpc(0,'state',{room_id:r.id});
 const room_id=r.id,code=r.code,room={room_id};
 check(rpc(0,'create',{map:'lotus_marsh'}).id===room_id,'lost create acknowledgment resumes same room');
 check(rpc(0,'create',{map:'river'}).error==='already_in_match','one active room per identity');
 check(rpc(0,'start',room).error==='players_not_ready','cannot start alone');
 check(rpc(1,'join',{code:'INVALID000'}).error==='room_not_found','bad room code');
 for(const invalidCode of ['1234','123456','12A45','１２３４５'])check(rpc(1,'join',{code:invalidCode}).error==='room_not_found','reject malformed five digit code '+invalidCode);
 for(let i=1;i<5;i++)check(rpc(i,'join',{code}).members.length===i+1,'join member '+(i+1));
 check(rpc(5,'join',{code}).error==='room_full','sixth player rejected');
 check(rpc(1,'start',room).error==='host_only','guest cannot start room');
 check(rpc(6,'state',room).error==='not_a_member','nonmember cannot read room');
 check(rpc(0,'state',{...room,token:'f'.repeat(64)}).error==='invalid_credentials','wrong guest token rejected even with JWT');
 check(sql(`set role authenticated;set request.jwt.claim.sub='${uid(6)}';select public.lakebound_match_channel('match:${room_id}');`).split('\n').at(-1)==='f','Realtime outsider denied');
 check(sql(`set role authenticated;set request.jwt.claim.sub='${uid(0)}';select public.lakebound_match_channel('match:${room_id}');`).split('\n').at(-1)==='t','Realtime member admitted');
 check(sql("select has_table_privilege('authenticated','lakebound_private.match_catches','insert');")==='f','client cannot bypass score RPC');
 check(sql("select has_function_privilege('anon','public.lakebound_matches(jsonb)','execute');")==='f','anonymous API key cannot call match RPC');
 for(let i=0;i<5;i++)rpc(i,'ready',{...room,ready:true});
 sql(`update lakebound_private.match_members set seen_at=clock_timestamp()-interval '30 seconds' where room_id='${room_id}' and player_id='${people[4].player_id}';`);
 check(rpc(0,'start',room).error==='players_not_ready','offline ready member blocks start');rpc(4,'state',room);
 check(rpc(0,'start',room).phase==='loading','ready group starts loading barrier');
 check(rpc(5,'join',{code}).error==='room_locked','late join rejected');
 for(let i=0;i<4;i++)check(rpc(i,'loaded',room).phase==='loading','waits for all map loads '+i);
 r=rpc(4,'loaded',room);check(r.phase==='countdown'&&r.ends_at-r.starts_at===600,'last load starts shared five second countdown and ten minute clock');
 const caught={...room,round_id:r.round_id,catch_id:'a'.repeat(32),species:'tilapia',grams:1234};
 check(rpc(0,'catch',caught).error==='outside_match','countdown catch rejected');
 sql(`update lakebound_private.match_rooms set starts_at=clock_timestamp()-interval '1 second',ends_at=clock_timestamp()+interval '10 minutes' where id='${room_id}';`);
 r=rpc(0,'catch',caught);check(r.members[0].grams===1234&&r.phase==='running','in-round catch credited');
 check(rpc(0,'catch',caught).members[0].grams===1234,'catch retry idempotent');
 check(rpc(0,'catch',{...caught,grams:9999}).error==='conflicting_catch','same catch cannot mutate');
 for(const [i,g]of [1000,2000,3000].entries())rpc(0,'catch',{...caught,catch_id:String(i+1).repeat(32),grams:g});
 r=rpc(0,'state',room);check(r.members[0].grams===6234&&r.members[0].best.join(',')==='3000,2000,1234','only three heaviest count');
 for(const [i,g]of [1234,2000,3000].entries())rpc(1,'catch',{...caught,catch_id:String(i+5).repeat(32),grams:g});
 r=rpc(1,'state',room);check(r.members.filter(m=>m.rank===1).length===2,'identical top three share rank');
 check(rpc(0,'catch',{...caught,catch_id:'f'.repeat(32),grams:1.5}).error==='invalid_catch','fractional grams rejected');
 check(rpc(0,'catch',{...caught,catch_id:'f'.repeat(32),species:'unknown'}).error==='invalid_catch','unknown species rejected');
 check(rpc(0,'leave',room).phase==='running','host leaving does not stop active round');
 check(rpc(0,'state',room).error==='not_a_member','departed member cannot submit/read');
 sql(`update lakebound_private.match_rooms set ends_at=clock_timestamp()-interval '1 second' where id='${room_id}';`);
 check(rpc(1,'catch',{...caught,catch_id:'e'.repeat(32)}).error==='outside_match','late catch rejected by database time');
 check(rpc(1,'state',room).phase==='finished','state recovers finalization after everyone disconnects');
 r=rpc(1,'rematch',room);check(r.phase==='lobby'&&r.round_id!==caught.round_id&&r.members.every(m=>!m.ready&&m.grams===0),'rematch resets score/readiness with a new round identifier');
 check(rpc(1,'catch',caught).error==='wrong_round','delayed old round catch cannot enter rematch');
 for(let i=1;i<5;i++)rpc(i,'leave',room);
 let other=rpc(5,'create',{map:'river'});let otherRoom={room_id:other.id};rpc(6,'join',{code:other.code});
 check(rpc(5,'leave',otherRoom).host===people[6].player_id,'lobby host transfers on leave');
 check(rpc(6,'leave',otherRoom).phase==='cancelled','empty lobby closes');
 const concurrentRoom=rpc(6,'create',{map:'river'});
 const joins=await Promise.all(Array.from({length:5},(_,i)=>new Promise((resolve,reject)=>{
  const command=`set role authenticated;set request.jwt.claim.sub='${uid(i)}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';select public.lakebound_matches(${q({...people[i],op:'join',code:concurrentRoom.code})});`;
  const child=spawn(path.join(bin,'psql.exe'),['-h','127.0.0.1','-p',port,'-U','postgres','-X','-A','-t','-v','ON_ERROR_STOP=1'],{windowsHide:true});
  let out='',err='';child.stdout.on('data',b=>out+=b);child.stderr.on('data',b=>err+=b);child.on('error',reject);child.on('exit',code=>code?reject(Error(err)):resolve(JSON.parse(out.trim().split('\n').at(-1))));child.stdin.end(command);
 })));
 check(joins.filter(r=>!r.error).length===4&&joins.filter(r=>r.error==='room_full').length===1,'simultaneous joins cannot exceed five players');
 check(rpc(6,'state',{room_id:concurrentRoom.id}).members.length===5,'room remains consistent after concurrent join race');
 sql(`update lakebound_private.match_members set seen_at=clock_timestamp()-interval '70 seconds' where room_id='${concurrentRoom.id}' and player_id='${people[6].player_id}';`);
 const survivor=joins.findIndex(r=>!r.error);
 r=rpc(survivor,'state',{room_id:concurrentRoom.id});check(r.host!==people[6].player_id&&r.members.length===4,'stale lobby host transfers and timed-out member is removed');
 await require('./test_match_options_cases.cjs')({sql,q,rpc,account,people,uid,check});
 await require('./test_match_fish_cases.cjs')({sql,q,rpc,people,uid,check});
 await require('./test_match_motion_cases.cjs')({sql,q,rpc,people,uid,check});
 await require('./test_match_rtc_cases.cjs')({sql,q,rpc,people,uid,check});
 sql(fs.readFileSync(path.join(__dirname,'migrations','202611030016_match_capacity.sql'),'utf8'));
 await require('./test_match_capacity_cases.cjs')({sql,q,check});
 const edgeIdentity=JSON.parse(sql(`set role authenticated;set request.jwt.claim.sub='${uid(0)}';set request.jwt.claims='{"app_metadata":{"provider":"google"},"exp":2000000000}';select public.lakebound_edge_identity();`).split('\n').at(-1));
 check(edgeIdentity.id===people[0].player_id&&edgeIdentity.expires_at===2000000000&&!Object.hasOwn(edgeIdentity,'token'),'edge identity binds Google account without exposing permanent profile token');
 check(sql("select has_function_privilege('anon','public.lakebound_edge_identity()','execute');")==='f','edge identity rejects anonymous callers');
 check(JSON.parse(sql(`set role authenticated;set request.jwt.claim.sub='${uid(0)}';set request.jwt.claims='{"app_metadata":{"provider":"email"}}';select public.lakebound_edge_identity();`).split('\n').at(-1)).error==='google_login_required','edge identity retains Google-only login policy');
 console.log('MATCH DATABASE RESULT: '+checks+' passed');
}finally{try{run('pg_ctl',['-D',dir,'-m','immediate','-w','stop']);}catch{}console.log('Stopped disposable cluster: '+dir);}}
main().catch(error=>{console.error(error);process.exitCode=1;});
