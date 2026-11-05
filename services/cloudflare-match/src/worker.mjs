import {DurableObject} from 'cloudflare:workers';
import {Registry} from './registry.mjs';
import {SocialGraph} from './social.mjs';
const json=(value,status=200)=>new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*'}});
const hash=async value=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),b=>b.toString(16).padStart(2,'0')).join('');
const uid=()=>crypto.randomUUID().replaceAll('-','')+crypto.randomUUID().replaceAll('-','');
const now=()=>Date.now()/1000;
export default {
 async fetch(request,env){
  const url=new URL(request.url);
  if(request.method==='OPTIONS')return new Response(null,{headers:{'Access-Control-Allow-Origin':'*','Access-Control-Allow-Methods':'GET, POST, OPTIONS','Access-Control-Allow-Headers':'Authorization, Content-Type','Access-Control-Max-Age':'600'}});
  if(url.pathname==='/health')return json({service:'lakebound-matches',protocol:1,max_players:Number(env.MAX_PLAYERS||100),max_rooms:Number(env.MAX_ROOMS||20),turn_configured:Boolean(env.CF_TURN_KEY_ID&&env.CF_TURN_API_TOKEN)});
  const stub=env.MATCHES.get(env.MATCHES.idFromName('lakebound-v1'));
  if(url.pathname==='/v1/socket'&&request.headers.get('Upgrade')?.toLowerCase()==='websocket')return stub.fetch(request);
  if(url.pathname!=='/v1/session'||request.method!=='POST')return json({error:'not_found'},404);
  if(Number(request.headers.get('content-length')||0)>1024)return json({error:'invalid_payload'},413);
  const auth=request.headers.get('Authorization')||'';
  if(!/^Bearer [A-Za-z0-9_.-]{20,8192}$/.test(auth))return json({error:'google_login_required'},401);
  try{
   // No service role or profile secret. Supabase verifies the JWT and binds identity.
   const response=await fetch(env.SUPABASE_URL+'/rest/v1/rpc/lakebound_edge_identity',{method:'POST',headers:{'Content-Type':'application/json',apikey:env.SUPABASE_PUBLISHABLE_KEY,Authorization:auth},body:'{}',signal:AbortSignal.timeout(8000)});
   if(!response.ok)return json({error:response.status===401?'jwt_expired':'identity_unavailable'},response.status===401?401:503);
   const identity=await response.json();
   if(identity.error||!/^[a-f0-9]{32}$/.test(identity.id)||typeof identity.name!=='string'||identity.name.length>80||!Number.isFinite(identity.expires_at)||identity.expires_at<now()+30)return json({error:identity.error||'google_login_required'},401);
   return json(await stub.ticket({id:identity.id,name:identity.name,expires_at:identity.expires_at}));
  }catch{return json({error:'identity_unavailable'},503);}
 }
};
export class LakeboundMatches extends DurableObject {
 constructor(ctx,env){
  super(ctx,env);this.ctx=ctx;this.env=env;this.registry=null;
  ctx.blockConcurrencyWhile(async()=>{await this.restore();this.syncPresence();this.registry.cleanup();await this.persist();});
  ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping','pong'));
 }
 async restore(){
  const rows=await this.ctx.storage.list({prefix:'room:',limit:40});
  this.registry=new Registry({rooms:[...rows.values()],maxPlayers:Math.min(100,Math.max(2,Number(this.env.MAX_PLAYERS||100))),maxRooms:Math.min(20,Math.max(1,Number(this.env.MAX_ROOMS||20))),acceptsNew:this.env.ACCEPTS_NEW!=='false'});
  this.social=new SocialGraph(this.ctx.storage,this.registry);
 }
 sockets(){return this.ctx.getWebSockets().filter(s=>s.readyState===1);}
 attachment(s){try{return s.deserializeAttachment()||{};}catch{return {};}}
 syncPresence(){this.registry.presence(this.sockets().map(s=>this.attachment(s)).filter(a=>a.identity&&a.identity.expires_at>now()).map(a=>a.identity.id));}
 async persist(){
  const {dirty,deleted}=this.registry;
  if(!dirty.size&&!deleted.size)return;
  await this.ctx.storage.transaction(async tx=>{
   for(const id of deleted)await tx.delete('room:'+id);
   for(const id of dirty){const r=this.registry.rooms.get(id);if(r)await tx.put('room:'+id,r);}
  });dirty.clear();deleted.clear();
  if(!await this.ctx.storage.getAlarm())await this.ctx.storage.setAlarm(Date.now()+3600000);
 }
 async ticket(identity){
  return this.ctx.blockConcurrencyWhile(async()=>{
   // An RPC method is callable only through this Worker's binding, not HTTP.
   if(!identity||!/^[a-f0-9]{32}$/.test(identity.id))return {error:'google_login_required'};
   const pending=await this.ctx.storage.list({prefix:'ticket:',limit:201});
   for(const [key,t]of pending)if(t.until<now())await this.ctx.storage.delete(key);
   if([...pending.values()].filter(t=>t.until>=now()).length>=200)return {error:'capacity_full'};
   const ticket=uid();await this.ctx.storage.put('ticket:'+await hash(ticket),{identity,until:now()+30});
   return {ticket,expires_in:30,protocol:1};
  });
 }
 async fetch(request){
  if(new URL(request.url).pathname!=='/v1/socket'||request.headers.get('Upgrade')?.toLowerCase()!=='websocket')return json({error:'not_found'},404);
  for(const s of this.sockets()){const a=this.attachment(s);if((!a.identity&&now()-a.opened>15)||(a.identity&&a.identity.expires_at<=now()))s.close(4000,'session_expired');}
  if(this.sockets().length>=120)return json({error:'capacity_full'},503);
  const pair=new WebSocketPair(),[client,server]=Object.values(pair);this.ctx.acceptWebSocket(server);server.serializeAttachment({opened:now(),window:now(),count:0});return new Response(null,{status:101,webSocket:client});
 }
 send(socket,value){try{socket.send(JSON.stringify(value));}catch{}}
 publish(room){
  for(const s of this.sockets()){const a=this.attachment(s);if(a.identity&&a.identity.expires_at>now()&&room.members.some(m=>m.id===a.identity.id&&!m.departed))this.send(s,{type:'snapshot',room:this.registry.snapshot(room)});}
 }
 async publishSocial(ids){
  for(const pid of new Set(ids)){
   const sockets=this.sockets().filter(s=>{const a=this.attachment(s);return a.identity?.id===pid&&a.identity.expires_at>now();});
   if(sockets.length){const state=await this.social.snapshot(pid);for(const s of sockets)this.send(s,{type:'social',state});}
  }
 }
 async publishPresence(pid){
  const graph=await this.social.record(pid),status=this.social.status(pid);
  for(const s of this.sockets()){const a=this.attachment(s);if(a.identity?.expires_at>now()&&graph.friends.includes(a.identity.id))this.send(s,{type:'friend_presence',id:pid,status});}
 }
 async webSocketMessage(socket,raw){
  await this.ctx.blockConcurrencyWhile(async()=>{
   let a=this.attachment(socket),message;
   if(typeof raw!=='string'||new TextEncoder().encode(raw).length>49152){socket.close(4002,'invalid_payload');return;}
   try{message=JSON.parse(raw);}catch{socket.close(4002,'invalid_payload');return;}
   if(!message||typeof message!=='object'||Array.isArray(message)){socket.close(4002,'invalid_payload');return;}
   const reply=value=>this.send(socket,{type:'reply',request_id:message.request_id,result:value});
   if(!a.identity){
    if(message.type!=='auth'||typeof message.ticket!=='string'||!/^[a-f0-9]{64}$/.test(message.ticket)||now()-a.opened>15){socket.close(4003,'google_login_required');return;}
    const key='ticket:'+await hash(message.ticket),ticket=await this.ctx.storage.get(key);await this.ctx.storage.delete(key);
    if(!ticket||ticket.until<now()||ticket.identity.expires_at<=now()){socket.close(4003,'session_expired');return;}
    for(const s of this.sockets())if(s!==socket&&this.attachment(s).identity?.id===ticket.identity.id)s.close(4001,'superseded_session');
    if(this.sockets().filter(s=>this.attachment(s).identity).length>=this.registry.maxPlayers){socket.close(4004,'capacity_full');return;}
    await this.social.profile(ticket.identity);
    a={...a,identity:ticket.identity};socket.serializeAttachment(a);this.syncPresence();this.send(socket,{type:'authenticated',server_time:now()});
    await this.publishSocial([a.identity.id]);await this.publishPresence(a.identity.id);return;
   }
   if(a.identity.expires_at<=now()){socket.close(4003,'jwt_expired');return;}
   if(now()-a.window>=1){a.window=now();a.count=0;}
   if(++a.count>12){socket.serializeAttachment(a);reply({error:'rate_limited'});return;}socket.serializeAttachment(a);
   this.syncPresence();
   try{
    if(message.type==='command'){
     const result=this.registry.command(a.identity,message.payload);
     const changed=[...this.registry.dirty];await this.persist();reply(result);
     for(const id of changed){const r=this.registry.rooms.get(id);if(r)this.publish(r);}
     if(!result.error&&['create','join','quick_join','leave','start','loaded','rematch'].includes(message.payload?.op)){
      const ids=['start','loaded','rematch'].includes(message.payload.op)?result.members.map(m=>m.id):[a.identity.id];
      for(const pid of ids)await this.publishPresence(pid);
     }
    }else if(message.type==='social'){
     const result=await this.social.command(a.identity,message.payload);
     if(result.error)reply(result);
     else{
      if(result.join){
       const joined=this.registry.command(a.identity,{op:'join',code:result.join.code});
       if(joined.error){reply(joined);return;}
       await this.persist();await this.social.consumeInvite(a.identity.id,result.join.id);reply({ok:true,room:joined});
       this.publish(this.registry.rooms.get(joined.id));await this.publishPresence(a.identity.id);
      }else reply({ok:true});
      await this.publishSocial(result.changed);
     }
    }else if(message.type==='rtc')reply(this.rtc(socket,a,message.payload));
    else if(message.type==='turn')reply(await this.turn(a.identity,message.payload));
    else if(message.type==='pose')this.pose(socket,a,message.payload);
    else reply({error:'invalid_op'});
    // RTC/TURN/pose membership checks can also retire an empty/expired room.
    // Flush deletions so hibernation cannot bring that room back.
    await this.persist();
   }catch{
    // A failed durable write must not acknowledge an uncommitted catch.
    await this.restore();this.syncPresence();reply({error:'busy_retry'});
   }
  });
 }
 member(identity,payload){
  this.registry.cleanup();const r=this.registry.rooms.get(payload?.room_id);
  if(!r||!r.members.some(m=>m.id===identity.id&&!m.departed))return {error:'not_a_member'};
  if(payload.round_id!==r.round_id)return {error:'wrong_round'};
  if(!['lobby','loading','countdown','running'].includes(r.phase))return {error:'outside_match'};
  return r;
 }
 rtc(socket,a,p){
  const r=this.member(a.identity,p);if(r.error)return r;
  if(!p||!/^[a-f0-9]{32}$/.test(p.session_id)||!['open','poll','send','close'].includes(p.op))return {error:'invalid_rtc_payload'};
  if(p.op==='open'){a.rtc={room:r.id,round:r.round_id,session:p.session_id};socket.serializeAttachment(a);}
  else if(a.rtc?.session!==p.session_id||a.rtc?.round!==r.round_id)return {error:'stale_rtc_session'};
  if(p.op==='close'){delete a.rtc;socket.serializeAttachment(a);return {ok:true};}
  const peers=this.sockets().filter(s=>{const other=this.attachment(s);return other.identity?.expires_at>now()&&other.rtc?.room===r.id&&other.rtc?.round===r.round_id&&r.members.some(m=>m.id===other.identity.id&&!m.departed);});
  if(p.op==='send'){
   if(!Array.isArray(p.items)||p.items.length>16)return {error:'invalid_rtc_payload'};
   // Validate the entire batch before forwarding any part.
   if(p.items.some(m=>!m||!['offer','answer','candidate'].includes(m.kind)||JSON.stringify(m.data||'').length>18000||(['offer','answer'].includes(m.kind)?typeof m.data!=='string'||m.data.length>16000:!m.data||typeof m.data.mid!=='string'||!Number.isInteger(m.data.index)||typeof m.data.candidate!=='string'||m.data.candidate.length>2048)))return {error:'invalid_rtc_payload'};
   for(const m of p.items){const to=peers.find(s=>{const other=this.attachment(s);return other.identity.id===m.to&&other.rtc.session===m.to_session&&s!==socket;});if(to)this.send(to,{type:'rtc_signal',room_id:r.id,round_id:r.round_id,message:{from:a.identity.id,session:p.session_id,kind:m.kind,data:m.data}});}
  }
  return {room_id:r.id,round_id:r.round_id,peers:peers.map(s=>{const x=this.attachment(s);return {player_id:x.identity.id,session_id:x.rtc.session};}),signals:[]};
 }
 pose(socket,a,p){
  const r=this.member(a.identity,{room_id:p?.room_id,round_id:p?.round});if(r.error)return;
  if(r.phase!=='running'||p.id!==a.identity.id||!Number.isSafeInteger(p.seq)||p.seq<0||p.seq<=(a.pose_seq??-1)||!Array.isArray(p.p)||p.p.length!==3||p.p.some(v=>!Number.isFinite(v)||Math.abs(v)>100000)||!Number.isFinite(p.yaw)||!Number.isFinite(p.speed)||p.speed<0||p.speed>50||!Number.isInteger(p.state)||p.state<0||p.state>10||JSON.stringify(p).length>1024)return;
  if(now()-(a.pose_at||0)<4.9)return; // Bound fallback; 20Hz stays peer-to-peer.
  a.pose_at=now();a.pose_seq=p.seq;socket.serializeAttachment(a);
  for(const other of this.sockets())if(other!==socket&&r.members.some(m=>!m.departed&&m.id===this.attachment(other).identity?.id))this.send(other,{type:'pose',pose:p});
 }
 async turn(identity,p){
  const r=this.member(identity,p);if(r.error)return r;
  if(this.env.ENVIRONMENT==='test')return {iceServers:[{urls:['stun:stun.cloudflare.com:3478']}],expiresIn:3300};
  if(!this.env.CF_TURN_KEY_ID||!this.env.CF_TURN_API_TOKEN)return {error:'turn_not_configured'};
  const cached=await this.ctx.storage.get('turn:'+identity.id);
  if(cached?.expires_at>now()+120)return {iceServers:cached.iceServers,expiresIn:Math.floor(cached.expires_at-now())};
  const day=new Date().toISOString().slice(0,10),key='turn_usage:'+day;
  const usage=await this.ctx.storage.get(key)||{total:0,players:{}};
  const user=usage.players[identity.id]||{count:0,last:0};
  if(usage.total>=Number(this.env.TURN_DAILY_LIMIT||3000)||user.count>=6||now()-user.last<60)return {error:'turn_daily_limit'};
  usage.total++;usage.players[identity.id]={count:user.count+1,last:now()};await this.ctx.storage.put(key,usage);
  const response=await fetch('https://rtc.live.cloudflare.com/v1/turn/keys/'+encodeURIComponent(this.env.CF_TURN_KEY_ID)+'/credentials/generate',{method:'POST',headers:{Authorization:'Bearer '+this.env.CF_TURN_API_TOKEN,'Content-Type':'application/json'},body:JSON.stringify({ttl:3600}),signal:AbortSignal.timeout(6000)});
  if(!response.ok)return {error:'turn_unavailable'};
  const value=await response.json();if(!value.iceServers)return {error:'turn_unavailable'};
  const iceServers=Array.isArray(value.iceServers)?value.iceServers:[value.iceServers];
  await this.ctx.storage.put('turn:'+identity.id,{iceServers,expires_at:now()+3300});return {iceServers,expiresIn:3300};
 }
 async webSocketClose(socket,code=1000,reason=''){
  // Complete the closing handshake; a half-closed socket must not retain a room.
  try{socket.close(code===1005?1000:code,reason);}catch{}
  await this.ctx.blockConcurrencyWhile(async()=>{
   const a=this.attachment(socket);if(!a.identity)return;
   this.syncPresence();if(this.registry.online.has(a.identity.id))return;
   this.registry.disconnect(a.identity.id);await this.persist();
   await this.publishPresence(a.identity.id);
   for(const r of this.registry.rooms.values())if(r.members.some(m=>m.id===a.identity.id))this.publish(r);
  });
 }
 async webSocketError(socket){await this.webSocketClose(socket);}
 async alarm(){
  this.syncPresence();this.registry.cleanup();await this.persist();
  const today=new Date().toISOString().slice(0,10);
  for(const [key]of await this.ctx.storage.list({prefix:'turn_usage:'}))if(key!=='turn_usage:'+today)await this.ctx.storage.delete(key);
  for(const prefix of ['ticket:','turn:'])for(const [key,value]of await this.ctx.storage.list({prefix}))if((value.until||value.expires_at)<now())await this.ctx.storage.delete(key);
  if(this.registry.rooms.size||this.sockets().length)await this.ctx.storage.setAlarm(Date.now()+3600000);
 }
}
