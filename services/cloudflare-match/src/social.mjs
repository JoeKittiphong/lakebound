// Private, durable friendship graph. Presence is derived from authenticated sockets.
const error=error=>({error});
export class SocialGraph {
 constructor(storage,registry,now=()=>Date.now()/1000){this.storage=storage;this.registry=registry;this.now=now;}
 async profile(identity){
  const key='social_profile:'+identity.id;let profile=await this.storage.get(key);
  if(!profile){
   let code=identity.id.slice(0,8).toUpperCase();
   while(await this.storage.get('social_code:'+code))code=crypto.randomUUID().replaceAll('-','').slice(0,8).toUpperCase();
   profile={id:identity.id,name:identity.name,code};
   await this.storage.transaction(async tx=>{await tx.put(key,profile);await tx.put('social_code:'+code,identity.id);});
  }else if(profile.name!==identity.name){profile.name=identity.name;await this.storage.put(key,profile);}
  return profile;
 }
 async record(pid){return await this.storage.get('social_graph:'+pid)||{friends:[],incoming:[],outgoing:[],day:'',sent:0};}
 status(pid){if(!this.registry.online.has(pid))return 'offline';const r=this.registry.current(pid);return !r?'online':r.phase==='lobby'?'in_room':'playing';}
 async snapshot(pid){
  const own=await this.storage.get('social_profile:'+pid),graph=await this.record(pid);
  const ids=[...new Set([...graph.friends,...graph.incoming,...graph.outgoing])];
  const profiles=ids.length?await this.storage.get(ids.map(id=>'social_profile:'+id)):new Map();
  const rows=list=>list.map(id=>profiles.get('social_profile:'+id)).filter(Boolean).map(p=>({id:p.id,name:p.name,code:p.code,status:graph.friends.includes(p.id)?this.status(p.id):'unknown'}));
  const invitations=(await this.storage.get('social_invites:'+pid)||[]).filter(i=>i.expires_at>this.now()&&graph.friends.includes(i.from)&&this.validInvite(i));
  return {self:own,friends:rows(graph.friends),incoming:rows(graph.incoming),outgoing:rows(graph.outgoing),invites:invitations,server_time:this.now()};
 }
 validInvite(i){const r=this.registry.rooms.get(i.room_id);return r&&r.round_id===i.round_id&&r.phase==='lobby'&&r.members.some(m=>m.id===i.from&&!m.departed)&&this.registry.online.has(i.from);}
 async command(identity,p){
  if(!p||typeof p!=='object'||JSON.stringify(p).length>1024)return error('invalid_payload');
  const pid=identity.id,g=await this.record(pid);let op=p.op;
  if(op==='state')return {changed:[pid]};
  if(op==='invite'){
   const target=p.friend_id;if(!g.friends.includes(target))return error('not_a_friend');
   const r=this.registry.current(pid);
   if(!r||r.phase!=='lobby')return error('invite_lobby_only');
   if(!this.registry.online.has(target))return error('friend_offline');
   if(this.registry.current(target))return error('friend_busy');
   if(r.members.filter(m=>!m.departed).length>=5)return error('room_full');
   let invites=(await this.storage.get('social_invites:'+target)||[]).filter(i=>i.expires_at>this.now()&&i.from!==pid);
   if(invites.length>=10)return error('invite_limit');
   const profile=await this.storage.get('social_profile:'+pid);
   invites.push({id:crypto.randomUUID(),from:pid,name:profile.name,room_id:r.id,round_id:r.round_id,code:r.code,expires_at:this.now()+60});
   await this.storage.put('social_invites:'+target,invites);return {changed:[pid,target]};
  }
  if(['accept_invite','decline_invite'].includes(op)){
   const key='social_invites:'+pid,invites=await this.storage.get(key)||[],invitation=invites.find(i=>i.id===p.invite_id);
   if(op==='decline_invite'){await this.storage.put(key,invites.filter(i=>i.id!==p.invite_id));return {changed:[pid]};}
   if(!invitation||invitation.expires_at<=this.now()||!g.friends.includes(invitation.from)||!this.validInvite(invitation))return error('invite_expired');
   if(this.registry.current(pid))return error('already_in_match');
   return {join:invitation,changed:[pid,invitation.from]};
  }
  let target=p.friend_id;
  if(op==='request_member'){
   const room=this.registry.rooms.get(p.room_id);
   if(!room||!room.members.some(m=>m.id===pid&&!m.departed)||!room.members.some(m=>m.id===target&&!m.departed))return error('not_a_room_member');
   op='request';
  }
  if(op==='request'&&p.op!=='request_member'){
   const code=String(p.code||'').trim().toUpperCase();
   if(!/^[A-F0-9]{8}$/.test(code))return error('invalid_friend_code');
   target=await this.storage.get('social_code:'+code);if(!target)return error('friend_not_found');
  }
  if(typeof target!=='string'||!/^[a-f0-9]{32}$/.test(target)||target===pid)return error('invalid_friend');
  const other=await this.record(target);
  if(op==='request'){
   if(g.friends.includes(target)||g.outgoing.includes(target))return {changed:[pid]};
   if(g.incoming.includes(target))return error('friend_request_pending');
   if(g.friends.length>=100||other.friends.length>=100||g.outgoing.length>=20||other.incoming.length>=30)return error('friend_limit');
   const day=new Date(this.now()*1000).toISOString().slice(0,10);if(g.day!==day){g.day=day;g.sent=0;}
   if(g.sent>=30)return error('friend_daily_limit');g.sent++;
   g.outgoing.push(target);other.incoming.push(pid);
  }else if(op==='accept'){
   if(!g.incoming.includes(target)||!other.outgoing.includes(pid))return error('friend_request_missing');
   if(g.friends.length>=100||other.friends.length>=100)return error('friend_limit');
   g.incoming=g.incoming.filter(id=>id!==target);other.outgoing=other.outgoing.filter(id=>id!==pid);
   if(!g.friends.includes(target))g.friends.push(target);if(!other.friends.includes(pid))other.friends.push(pid);
  }else if(op==='decline'||op==='cancel'){
   if(op==='decline'){g.incoming=g.incoming.filter(id=>id!==target);other.outgoing=other.outgoing.filter(id=>id!==pid);}
   else{g.outgoing=g.outgoing.filter(id=>id!==target);other.incoming=other.incoming.filter(id=>id!==pid);}
  }else if(op==='remove'){
   g.friends=g.friends.filter(id=>id!==target);other.friends=other.friends.filter(id=>id!==pid);
  }else return error('invalid_op');
  await this.storage.transaction(async tx=>{
   await tx.put('social_graph:'+pid,g);await tx.put('social_graph:'+target,other);
   if(op==='remove')for(const [owner,from]of [[pid,target],[target,pid]]){const key='social_invites:'+owner;await tx.put(key,(await tx.get(key)||[]).filter(i=>i.from!==from));}
  });
  return {changed:[pid,target]};
 }
 async consumeInvite(pid,id){const key='social_invites:'+pid;await this.storage.put(key,(await this.storage.get(key)||[]).filter(i=>i.id!==id));}
}
