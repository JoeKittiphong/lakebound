const {spawn}=require('node:child_process'),path=require('node:path');
module.exports=async function({sql,q,check}){
 const clean=()=>sql("update lakebound_private.match_rooms set phase='cancelled';truncate lakebound_private.match_leases,lakebound_private.match_requests,lakebound_private.match_budget;update lakebound_private.match_limits set max_rooms=4,max_players=20,monthly_events=1500000,accepts_new=true;");
 const users=[];
 for(let i=0;i<21;i++){
  const uid='10000000-0000-4000-8000-'+String(i+1).padStart(12,'0');
  const a=JSON.parse(sql(`set role authenticated;set request.jwt.claim.sub='${uid}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';select public.lakebound_account('{}');`).split('\n').at(-1)).identity;
  users.push({uid,player_id:a.id,token:a.token,player_name:a.name});
 }
 const statement=(i,op,data={},endpoint='lakebound_matches')=>`set role authenticated;set request.jwt.claim.sub='${users[i].uid}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';select public.${endpoint}(${q({...users[i],uid:undefined,op,...data})});`;
 const rpc=(i,op,data={})=>JSON.parse(sql(`update lakebound_private.match_requests set window_at=clock_timestamp()-interval '2 seconds' where auth_id='${users[i].uid}';`+statement(i,op,data)).split('\n').at(-1));
 const parallel=ops=>Promise.all(ops.map(([i,op,data,endpoint])=>new Promise((resolve,reject)=>{
  const child=spawn(path.join(process.env.PG_BIN||'C:/Program Files/PostgreSQL/18/bin','psql.exe'),['-h','127.0.0.1','-p',process.env.LAKEBOUND_TEST_PG_PORT,'-U','postgres','-X','-A','-t','-v','ON_ERROR_STOP=1'],{windowsHide:true});
  let out='',err='';child.stdout.on('data',b=>out+=b);child.stderr.on('data',b=>err+=b);child.on('error',reject);child.on('exit',code=>code?reject(Error(err)):resolve(JSON.parse(out.trim().split('\n').at(-1))));child.stdin.end(statement(i,op,data,endpoint));
 })));
 check(sql('select max_rooms||\':\'||max_players from lakebound_private.match_limits;')==='4:20','capacity upgrade opens four rooms and twenty players');
 clean();
 const rooms=[];
 const started=Date.now();
 for(let i=0;i<4;i++)rooms.push(rpc(i*5,'create',{map:'river',duration:600}));
 check(rooms.every(r=>r.id&&r.pose_interval===2),'four rooms retain 20Hz RTC with two-second Broadcast fallback');
 check(sql('select sum(reserved) from lakebound_private.match_budget;')==='46800','four rounds reserve reduced worst-case fallback budget');
 const seats=[];for(let r=0;r<4;r++)for(let j=1;j<5;j++)seats.push([r*5+j,'join',{code:rooms[r].code}]);
 const joined=await parallel(seats);
 check(joined.every(r=>r.id),'sixteen simultaneous joins fill twenty seats across four rooms');
 check(rpc(20,'create',{map:'river'}).error==='capacity_full','twenty-first player cannot create fifth room');
 check(rpc(20,'quick_join').error==='no_open_rooms','quick join cannot overfill four full rooms');
 for(let cycle=0;cycle<3;cycle++){
  sql("update lakebound_private.match_requests set window_at=clock_timestamp()-interval '2 seconds';");
  const states=await parallel(Array.from({length:20},(_,i)=>[i,'state',{room_id:rooms[Math.floor(i/5)].id}]));
  check(states.every((r,i)=>r.id===rooms[Math.floor(i/5)].id&&r.members.length===5),'twenty concurrent state requests remain isolated, wave '+cycle);
 }
 check(rpc(0,'state',{room_id:rooms[1].id}).error==='not_a_member','other room snapshot stays private');
 const signaling=op=>Array.from({length:20},(_,i)=>[i,op,{room_id:rooms[Math.floor(i/5)].id,round_id:rooms[Math.floor(i/5)].round_id,session_id:(i+1).toString(16).padStart(32,'0')},'lakebound_rtc']);
 sql("update lakebound_private.match_requests set window_at=clock_timestamp()-interval '2 seconds';");
 check((await parallel(signaling('open'))).every((r,i)=>r.room_id===rooms[Math.floor(i/5)].id),'twenty peers register through authenticated RTC signaling concurrently');
 sql("update lakebound_private.match_requests set window_at=clock_timestamp()-interval '2 seconds';");
 check((await parallel(signaling('poll'))).every(r=>r.peers.length===5),'RTC rosters remain five peers per room across twenty accounts');
 sql("update lakebound_private.match_limits set monthly_events=46800;");
 check(rpc(0,'state',{room_id:rooms[0].id}).id===rooms[0].id,'reserved games continue at monthly budget ceiling');
 rpc(0,'leave',{room_id:rooms[0].id});
 check(rpc(20,'quick_join').id===rooms[0].id,'quick join fills a released seat without another reservation');
 check(sql('select sum(reserved) from lakebound_private.match_budget;')==='46800','replacing a departed member never charges the round twice');
 clean();let r=rpc(0,'create',{map:'river',duration:180});
 sql(`update lakebound_private.match_rooms set motion_interval=0.334 where id='${r.id}';`);
 check(rpc(5,'create',{map:'river'}).error==='capacity_full','legacy fast room blocks additional room fanout until it ends');
 sql(`update lakebound_private.match_rooms set phase='finished' where id='${r.id}';`);
 r=rpc(0,'rematch',{room_id:r.id});
 check(r.pose_interval===2&&!!rpc(5,'create',{map:'river'}).id,'legacy rematch switches to scalable reserved fallback');
 clean();sql('update lakebound_private.match_limits set monthly_events=5400;');
 const race=await parallel([[0,'create',{map:'river',duration:180}],[5,'create',{map:'river',duration:180}]]);
 check(race.filter(r=>r.id).length===1&&race.filter(r=>r.error==='monthly_capacity_reached').length===1,'concurrent new rooms cannot overspend reduced round budget');
 check(sql("select has_function_privilege('authenticated','public.lakebound_capacity_status()','execute');")==='f','capacity report is restricted to owner and server');
 const status=JSON.parse(sql('select public.lakebound_capacity_status();'));
 check(status.target_monthly_users===300&&status.active_rooms===1&&status.reserved_events===5400&&status.remaining_events===0,'owner report shows target, live capacity and rolling remaining budget');
 check(!JSON.stringify(status).includes('token'),'capacity report contains no player tokens');
 console.log('CAPACITY LOCAL LOAD: 20 accounts, 16 concurrent joins, 3 x 20 concurrent snapshots, '+(Date.now()-started)+' ms including process launch; not a hosted throughput benchmark');
 clean();
};
