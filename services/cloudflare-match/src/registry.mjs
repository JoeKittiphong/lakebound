import {speciesByMap} from './species.mjs';
const fail=error=>({error});
const active=r=>['lobby','loading','countdown','running'].includes(r.phase);
const number=(v,min,max)=>Number.isInteger(v)&&v>=min&&v<=max;
export class Registry {
 constructor({rooms=[],maxPlayers=100,maxRooms=20,acceptsNew=true,now=()=>Date.now()/1000,uuid=()=>crypto.randomUUID()}={}){
  this.rooms=new Map(rooms.map(r=>[r.id,r]));this.maxPlayers=maxPlayers;this.maxRooms=maxRooms;this.acceptsNew=acceptsNew;this.now=now;this.uuid=uuid;this.online=new Set();this.dirty=new Set();this.deleted=new Set();
 }
 presence(ids){this.online=new Set(ids);}
 current(pid){return [...this.rooms.values()].find(r=>active(r)&&r.members.some(m=>m.id===pid&&!m.departed));}
 touch(r){this.dirty.add(r.id);}
 disconnect(pid){for(const r of this.rooms.values()){const m=r.members.find(m=>m.id===pid&&!m.departed);if(m){m.seen=this.now();this.touch(r);}}this.cleanup();}
 discard(r){
  if(active(r)){r.phase='cancelled';r.finished_at=this.now();}
  for(const m of r.members)m.departed=true;
  r.claims={};r.catches={};
  this.rooms.delete(r.id);this.deleted.add(r.id);this.dirty.delete(r.id);
 }
 cleanup(){
  const now=this.now();
  for(const r of this.rooms.values()){
   // Reconnect grace applies only while somebody is still in the room.
   // An empty room owns no slot, code, fish state or resumable round.
   if(!r.members.some(m=>!m.departed&&this.online.has(m.id))){this.discard(r);continue;}
   if(r.phase==='countdown'&&now>=r.starts_at){r.phase='running';this.touch(r);}
   if(r.phase==='running'&&now>=r.ends_at){r.phase='finished';r.finished_at=now;this.touch(r);}
   if(r.phase==='loading'&&now-r.loading_at>90){r.phase='cancelled';r.finished_at=now;this.touch(r);}
   if(r.phase==='lobby'&&now-r.created_at>7200){r.phase='cancelled';r.finished_at=now;this.touch(r);}
   for(const m of r.members)if(active(r)&&!m.departed&&!this.online.has(m.id)&&now-m.seen>75){m.departed=true;this.touch(r);}
   if(active(r)&&!r.members.some(m=>!m.departed)){r.phase='cancelled';r.finished_at=now;this.touch(r);}
   if(!r.members.some(m=>m.id===r.host&&!m.departed)){const host=r.members.find(m=>!m.departed)?.id;if(host&&host!==r.host){r.host=host;this.touch(r);}}
   for(const [id,c] of Object.entries(r.claims))if(!c.landed&&c.expires_at<=now){delete r.claims[id];this.touch(r);}
   if(!active(r)&&now-(r.finished_at||r.ends_at||r.created_at)>3600){this.rooms.delete(r.id);this.deleted.add(r.id);this.dirty.delete(r.id);}
  }
  // Bound retained scoreboards as well as live rooms.
  const ended=[...this.rooms.values()].filter(r=>!active(r)).sort((a,b)=>(a.finished_at||0)-(b.finished_at||0));
  for(const r of ended.slice(0,Math.max(0,ended.length-20))){this.rooms.delete(r.id);this.deleted.add(r.id);this.dirty.delete(r.id);}
 }
 snapshot(r){
  const scores=r.members.map(m=>{
   const all=Object.values(r.catches).filter(c=>c[0]===m.id&&(r.rule!=='species_total'||c[1]===r.target_species)).map(c=>c[2]).sort((a,b)=>b-a);
   return {id:m.id,name:m.name,ready:m.ready,loaded:m.loaded,departed:m.departed,online:this.online.has(m.id),grams:r.rule==='biggest_fish'?(all[0]||0):all.reduce((a,b)=>a+b,0),best:all.slice(0,3)};
  }).sort((a,b)=>b.grams-a.grams||a.id.localeCompare(b.id));
  scores.forEach((m,i)=>m.rank=i>0&&m.grams===scores[i-1].grams?scores[i-1].rank:i+1);
  return {schema:1,transport:'cloudflare',id:r.id,code:r.code,host:r.host,map:r.map,phase:r.phase,seed:r.seed,round_id:r.round_id,duration:r.duration,rule:r.rule,target_species:r.target_species,server_time:this.now(),starts_at:r.starts_at||0,ends_at:r.ends_at||0,pose_interval:5,poll_interval:30,members:scores,
   fish_claims:Object.values(r.claims).filter(c=>!c.landed&&c.expires_at>this.now()).map(c=>[c.fish_id,c.player_id,c.claim_id,c.expires_at,c.species,c.grams]),consumed_fish:Object.values(r.claims).filter(c=>c.landed).map(c=>c.fish_id)};
 }
 command(who,p){
  this.cleanup();
  if(!who||!/^[a-f0-9]{32}$/.test(who.id)||typeof who.name!=='string')return fail('google_login_required');
  if(!p||typeof p!=='object'||JSON.stringify(p).length>4096)return fail('invalid_payload');
  const now=this.now(),op=p.op;let r=this.rooms.get(p.room_id),m;
  const existing=this.current(who.id);
  if(['create','join','quick_join'].includes(op)&&existing){
   if(op==='create'&&p.map&&p.map!==existing.map)return fail('already_in_match');
   return this.snapshot(existing);
  }
  if(op==='quick_join'){
   r=[...this.rooms.values()].find(r=>r.phase==='lobby'&&this.online.has(r.host)&&r.members.filter(m=>!m.departed).length<5);
   // Quick play creates a default room when none is open.
   if(!r)return this.command(who,{op:'create',map:p.map||'river',duration:p.duration??600,rule:p.rule||'total_weight',target_species:p.target_species||''});
  }
  if(op==='join'){if(typeof p.code!=='string'||!/^\d{5}$/.test(p.code))return fail('room_not_found');r=[...this.rooms.values()].find(r=>r.code===p.code);}
  if(op==='create'){
   if(!this.acceptsNew)return fail('capacity_full');
   if(!Object.hasOwn(speciesByMap,p.map))return fail('invalid_map');
   const duration=p.duration===undefined?600:p.duration,rule=p.rule??'total_weight',target=p.target_species||'';
   if(![180,300,600,900,1200].includes(duration))return fail('invalid_duration');
   if(!['species_total','total_weight','biggest_fish'].includes(rule))return fail('invalid_rule');
   if(rule==='species_total'?!speciesByMap[p.map].includes(target):target!=='')return fail('invalid_target_species');
   if([...this.rooms.values()].filter(active).length>=this.maxRooms||this.playerCount()>=this.maxPlayers)return fail('capacity_full');
   let code;for(let i=0;i<100;i++){code=String(crypto.getRandomValues(new Uint32Array(1))[0]%100000).padStart(5,'0');if(![...this.rooms.values()].some(r=>r.code===code))break;code=null;}
   if(!code)return fail('busy_retry');
   r={id:this.uuid(),code,host:who.id,map:p.map,duration,rule,target_species:target,phase:'lobby',seed:crypto.getRandomValues(new Uint32Array(1))[0]%2147483647,round_id:this.uuid(),created_at:now,starts_at:0,ends_at:0,members:[],claims:{},catches:{}};
   this.rooms.set(r.id,r);
  }
  if(!r)return fail('room_not_found');
  if(['create','join','quick_join'].includes(op)){
   if(!this.acceptsNew)return fail('capacity_full');
   if(r.phase!=='lobby')return fail('room_locked');
   if(r.members.filter(m=>!m.departed).length>=5)return fail('room_full');
   if(this.playerCount()>=this.maxPlayers)return fail('capacity_full');
   // Reuse the row when a departed player returns, preventing duplicate IDs.
   r.members=r.members.filter(m=>!m.departed&&m.id!==who.id);
   r.members.push({id:who.id,name:who.name,ready:false,loaded:false,departed:false,seen:now});this.touch(r);return this.snapshot(r);
  }
  m=r.members.find(m=>m.id===who.id&&!m.departed);
  if(!m)return fail('not_a_member');
  if(op==='state')return this.snapshot(r);
  if(op==='leave'){
   m.departed=true;for(const [id,c] of Object.entries(r.claims))if(c.player_id===who.id&&!c.landed)delete r.claims[id];this.touch(r);this.cleanup();return this.snapshot(r);
  }
  if(op==='ready'){
   if(r.phase!=='lobby')return fail('room_locked');if(typeof p.ready!=='boolean')return fail('invalid_payload');m.ready=p.ready;
  }else if(op==='start'){
   if(r.host!==who.id)return fail('host_only');if(r.phase!=='lobby')return this.snapshot(r);
   const players=r.members.filter(m=>!m.departed);
   if(players.length<2||players.some(m=>!m.ready||!this.online.has(m.id)))return fail('players_not_ready');
   r.phase='loading';r.loading_at=now;for(const member of players)member.loaded=false;
  }else if(op==='loaded'){
   if(r.phase!=='loading')return this.snapshot(r);m.loaded=true;
   if(r.members.filter(m=>!m.departed).every(m=>m.loaded&&this.online.has(m.id))){r.phase='countdown';r.starts_at=now+5;r.ends_at=r.starts_at+r.duration;}
  }else if(op==='rematch'){
   if(existing&&existing.id!==r.id)return fail('already_in_match');
   if(active(r))return this.snapshot(r);if(!this.acceptsNew||[...this.rooms.values()].filter(active).length>=this.maxRooms||this.playerCount()+r.members.filter(m=>!m.departed).length>this.maxPlayers)return fail('capacity_full');
   if(r.host!==who.id)return fail('host_only');
   r.members=r.members.filter(m=>!m.departed&&(!this.current(m.id)||this.current(m.id).id===r.id));
   r.phase='lobby';r.round_id=this.uuid();r.seed=crypto.getRandomValues(new Uint32Array(1))[0]%2147483647;r.created_at=now;r.starts_at=0;r.ends_at=0;r.claims={};r.catches={};for(const member of r.members){member.ready=false;member.loaded=false;member.seen=now;}
  }else if(['claim_fish','renew_fish','release_fish','catch'].includes(op)){
   if(p.round_id!==r.round_id)return fail('wrong_round');
   if(r.phase!=='running'||now>=r.ends_at)return fail('outside_match');
   if(!number(p.fish_id,1,100000))return fail('fish_claim_required');
   let claim=r.claims[p.fish_id];
   if(op==='claim_fish'){
    if(claim?.landed)return fail('fish_consumed');if(claim&&claim.player_id!==who.id)return fail('fish_taken');
    if(!speciesByMap[r.map].includes(p.species)||!number(p.grams,1,1000000000))return fail('invalid_catch');
    if(!claim){if(Object.values(r.claims).filter(c=>!c.landed).length>=20)return fail('fish_claim_limit');if(Object.keys(r.catches).length>=200)return fail('catch_limit');claim={fish_id:p.fish_id,player_id:who.id,claim_id:this.uuid(),expires_at:now+90,species:p.species,grams:p.grams,landed:false};r.claims[p.fish_id]=claim;}
   }else if(op==='catch'){
    if(typeof p.catch_id!=='string'||!/^[a-f0-9]{32}$/.test(p.catch_id))return fail('invalid_catch');
    const prev=r.catches[p.catch_id];
    if(prev){if(prev[0]!==who.id||prev[1]!==p.species||prev[2]!==p.grams||prev[3]!==p.fish_id||prev[4]!==p.claim_id)return fail('catch_conflict');return this.snapshot(r);}
    if(!claim||claim.player_id!==who.id||claim.claim_id!==p.claim_id||claim.expires_at<=now||claim.landed)return fail('fish_claim_required');
    if(claim.species!==p.species||claim.grams!==p.grams)return fail('fish_claim_mismatch');
    if(Object.keys(r.catches).length>=200)return fail('catch_limit');
    r.catches[p.catch_id]=[who.id,p.species,p.grams,p.fish_id,p.claim_id];claim.landed=true;
   }else{
    if(!claim||claim.player_id!==who.id||claim.claim_id!==p.claim_id||claim.landed)return fail('fish_claim_required');
    if(op==='release_fish')delete r.claims[p.fish_id];else claim.expires_at=now+90;
   }
  }else return fail('invalid_op');
  this.touch(r);return this.snapshot(r);
 }
 playerCount(){return [...this.rooms.values()].filter(active).reduce((n,r)=>n+r.members.filter(m=>!m.departed).length,0);}
}
