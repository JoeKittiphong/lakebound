module.exports=async function({sql,rpc,check}){
 sql("truncate lakebound_private.match_leases,lakebound_private.match_requests,lakebound_private.match_budget;update lakebound_private.match_rooms set phase='cancelled';update lakebound_private.match_limits set max_rooms=1,max_players=5,monthly_events=1500000,accepts_new=true;");
 let r=rpc(0,'create',{map:'river',duration:180});
 check(r.pose_interval===0.334,'new rooms advertise fast motion only after reservation');
 check(sql('select sum(reserved) from lakebound_private.match_budget;')==='32400','fast room reserves ninety events per second including margin');
 check(rpc(0,'create',{map:'river',duration:180}).id===r.id&&sql('select sum(reserved) from lakebound_private.match_budget;')==='32400','fast create retry does not spend budget twice');
 check(rpc(1,'create',{map:'river'}).error==='capacity_full','one fast room prevents another concurrent room');
 for(let i=1;i<5;i++)check(rpc(i,'join',{code:r.code}).id===r.id,'five-player fast room seat '+i);
 check(rpc(5,'join',{code:r.code}).error==='capacity_full','fast admission prevents sixth player');
 sql(`update lakebound_private.match_rooms set phase='finished',motion_interval=2.0 where id='${r.id}';`);
 r=rpc(0,'rematch',{room_id:r.id});
 check(r.pose_interval===0.334&&sql('select sum(reserved) from lakebound_private.match_budget;')==='64800','legacy rematch upgrades speed and reserves full new budget atomically');
 check(rpc(0,'state',{room_id:r.id}).pose_interval===0.334,'state preserves upgraded room interval');
 check(sql("select has_table_privilege('authenticated','lakebound_private.match_rooms','update');")==='f','clients cannot raise room motion frequency directly');
 check(5*5/0.334<75&&5*5/0.334+15<100,'full room estimated fanout leaves control traffic headroom');
 sql("update lakebound_private.match_rooms set phase='cancelled';truncate lakebound_private.match_leases;");
 const smoke=require('node:fs').readFileSync(require('node:path').join(__dirname,'check_match_motion.sql'),'utf8');
 check(sql(smoke).includes('fast_motion_smoke_passed'),'motion acceptance smoke rolls back all temporary accounts and reservations');
};
