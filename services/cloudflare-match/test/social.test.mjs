import test from 'node:test';import assert from 'node:assert/strict';import {runtime} from './runtime.mjs';
import {SocialGraph} from '../src/social.mjs';import {Registry} from '../src/registry.mjs';
const pid=i=>i.toString(16).padStart(32,'0');
test('friend consent, private presence, invitations, leaving, reconnect and durable graph',async()=>{
 const mf=runtime(),all=[];let sequence=0;
 const waitFor=async predicate=>{const end=Date.now()+3000;while(Date.now()<end){const value=predicate();if(value)return value;await new Promise(r=>setTimeout(r,10));}throw Error('social event timeout');};
 const connect=async i=>{
  const auth=await(await mf.dispatchFetch('http://local/v1/session',{method:'POST',headers:{Authorization:'Bearer qa.'+pid(i)+'.signature'},body:'{}'})).json();
  const socket=(await mf.dispatchFetch('http://local/v1/socket',{headers:{Upgrade:'websocket'}})).webSocket;socket.accept();
  const client={socket,messages:[],state:{}};const pending=new Map();let authenticated;
  const ready=new Promise(r=>authenticated=r);
  socket.addEventListener('message',event=>{
   const value=JSON.parse(event.data);client.messages.push(value);
   if(value.type==='authenticated')authenticated();
   if(value.type==='social')client.state=value.state;
   if(value.type==='friend_presence')for(const friend of client.state.friends||[])if(friend.id===value.id)friend.status=value.status;
   if(value.type==='reply'&&pending.has(value.request_id)){pending.get(value.request_id)(value.result);pending.delete(value.request_id);}
  });
  client.call=(type,payload)=>new Promise((resolve,reject)=>{const request_id=++sequence;const timer=setTimeout(()=>reject(Error('social RPC timeout')),10000);pending.set(request_id,v=>{clearTimeout(timer);resolve(v);});socket.send(JSON.stringify({type,request_id,payload}));});
  socket.send(JSON.stringify({type:'auth',ticket:auth.ticket}));await ready;await waitFor(()=>client.state.self);all.push(client);return client;
 };
 try{
  const a=await connect(1),b=await connect(2),c=await connect(3),code=b.state.self.code;
  assert.notEqual(code,a.state.self.code);assert.equal(a.state.friends.length,0);
  const publicRoom=await a.call('command',{op:'quick_join'}),strangerRoom=await b.call('command',{op:'quick_join'});
  assert.equal(strangerRoom.id,publicRoom.id);assert.equal(strangerRoom.members.length,2);
  assert.equal(a.state.friends.length,0);assert.equal(b.state.friends.length,0);
  assert.equal((await a.call('social',{op:'request_member',room_id:publicRoom.id,friend_id:pid(3)})).error,'not_a_room_member');
  assert.equal((await a.call('social',{op:'request_member',room_id:publicRoom.id,friend_id:pid(2)})).ok,true);
  await b.call('command',{op:'leave',room_id:publicRoom.id});
  assert.equal((await a.call('social',{op:'request',code:a.state.self.code})).error,'invalid_friend');
  assert.equal((await a.call('social',{op:'request',code,player_id:pid(3)})).ok,true);
  await waitFor(()=>b.state.incoming.length===1);assert.equal(b.state.incoming[0].id,pid(1));assert.equal(b.state.incoming[0].status,'unknown');
  assert.equal((await b.call('social',{op:'accept',friend_id:pid(1)})).ok,true);
  await waitFor(()=>a.state.friends.length===1&&b.state.friends.length===1);
  assert.equal(a.state.friends[0].status,'online');assert.equal(c.state.friends.length,0);
  const room=await a.call('command',{op:'quick_join'});await waitFor(()=>b.state.friends[0].status==='in_room');
  assert.equal((await c.call('social',{op:'invite',friend_id:pid(2)})).error,'not_a_friend');
  assert.equal((await a.call('social',{op:'invite',friend_id:pid(2)})).ok,true);
  await waitFor(()=>b.state.invites.length===1);const invitation=b.state.invites[0];
  assert.equal((await c.call('social',{op:'accept_invite',invite_id:invitation.id})).error,'invite_expired');
  const joined=await b.call('social',{op:'accept_invite',invite_id:invitation.id});assert.equal(joined.room.id,room.id);assert.equal(joined.room.members.length,2);
  assert.equal((await b.call('command',{op:'leave',room_id:room.id})).id,room.id);await waitFor(()=>a.state.friends[0].status==='online');
  // A member can leave a room while staying online in the friends list.
  assert.equal((await a.call('social',{op:'invite',friend_id:pid(2)})).ok,true);await waitFor(()=>b.state.invites.length===1);const stale=b.state.invites[0];
  await c.call('command',{op:'join',code:room.code});
  // Respect the per-connection burst policy rather than treating test traffic as gameplay.
  await new Promise(r=>setTimeout(r,1050));
  await a.call('command',{op:'ready',room_id:room.id,ready:true});await c.call('command',{op:'ready',room_id:room.id,ready:true});
  assert.equal((await a.call('command',{op:'start',room_id:room.id})).phase,'loading');
  assert.equal((await b.call('social',{op:'accept_invite',invite_id:stale.id})).error,'invite_expired');
  const closing=new Promise(resolve=>b.socket.addEventListener('close',resolve,{once:true}));b.socket.close();await closing;await waitFor(()=>a.state.friends[0].status==='offline');
  await mf.unsafeEvictDurableObject('lakebound-test','LakeboundMatches',{name:'lakebound-v1',webSockets:'hibernate'});
  await a.call('social',{op:'state'});assert.equal(a.state.friends[0].id,pid(2));
  const reconnected=await connect(2);assert.equal(reconnected.state.self.code,code);assert.equal(reconnected.state.friends[0].id,pid(1));await waitFor(()=>a.state.friends[0].status==='online');
  assert.equal((await a.call('social',{op:'remove',friend_id:pid(2)})).ok,true);await waitFor(()=>a.state.friends.length===0&&reconnected.state.friends.length===0);
  assert.equal((await a.call('social',{op:'invite',friend_id:pid(2)})).error,'not_a_friend');
 }finally{for(const c of all)if(c.socket.readyState===1)c.socket.close();await mf.dispose();}
});
test('invites expire after sixty seconds and cannot revive a deleted empty room',async()=>{
 let stamp=1000;const data=new Map();
 const storage={get:async key=>Array.isArray(key)?new Map(key.filter(k=>data.has(k)).map(k=>[k,structuredClone(data.get(k))])):structuredClone(data.get(key)),put:async(key,value)=>data.set(key,structuredClone(value)),transaction:async fn=>fn(storage)};
 const registry=new Registry({now:()=>stamp}),social=new SocialGraph(storage,registry,()=>stamp);
 const a={id:pid(1),name:'A'},b={id:pid(2),name:'B'};registry.presence([a.id,b.id]);
 await social.profile(a);const p=await social.profile(b);
 await social.command(a,{op:'request',code:p.code});await social.command(b,{op:'accept',friend_id:a.id});
 let room=registry.command(a,{op:'quick_join'});
 await social.command(a,{op:'invite',friend_id:b.id});let invite=(await social.snapshot(b.id)).invites[0];
 stamp+=61;assert.equal((await social.command(b,{op:'accept_invite',invite_id:invite.id})).error,'invite_expired');
 await social.command(a,{op:'invite',friend_id:b.id});invite=(await social.snapshot(b.id)).invites[0];
 registry.command(a,{op:'leave',room_id:room.id});assert.equal(registry.rooms.size,0);
 assert.equal((await social.command(b,{op:'accept_invite',invite_id:invite.id})).error,'invite_expired');
 room=registry.command(a,{op:'quick_join'});await social.command(a,{op:'invite',friend_id:b.id});
 await social.command(a,{op:'remove',friend_id:b.id});assert.equal((await social.snapshot(b.id)).invites.length,0);
 await social.command(a,{op:'request',code:p.code});await social.command(b,{op:'accept',friend_id:a.id});assert.equal((await social.snapshot(b.id)).invites.length,0);
});
