import test from 'node:test';import assert from 'node:assert/strict';import {runtime} from './runtime.mjs';
const id=i=>i.toString(16).padStart(32,'0');
test('real Durable Object WebSockets: 100 users, room privacy, RTC sender binding, reconnect and tickets',async()=>{
 const mf=runtime();const sockets=[];let seq=0;
 const connect=async i=>{
  const ticket=await (await mf.dispatchFetch('http://local/v1/session',{method:'POST',headers:{Authorization:'Bearer qa.'+id(i)+'.signature'},body:'{}'})).json();assert.ok(ticket.ticket,ticket.error);
  const response=await mf.dispatchFetch('http://local/v1/socket',{headers:{Upgrade:'websocket'}});const socket=response.webSocket;assert.ok(socket);socket.accept();
  const messages=[],waiting=new Map();let authenticated;
  const ready=new Promise(resolve=>authenticated=resolve);
  socket.addEventListener('message',event=>{if(event.data==='pong')return;const m=JSON.parse(event.data);messages.push(m);if(m.type==='authenticated')authenticated();if(m.type==='reply'){const resolve=waiting.get(m.request_id);if(resolve){waiting.delete(m.request_id);resolve(m.result);}}});
  socket.send(JSON.stringify({type:'auth',ticket:ticket.ticket}));await ready;
  const call=(type,payload)=>new Promise((resolve,reject)=>{const request_id=++seq;const timer=setTimeout(()=>{waiting.delete(request_id);reject(Error('RPC timeout'));},10000);waiting.set(request_id,v=>{clearTimeout(timer);resolve(v);});socket.send(JSON.stringify({type,request_id,payload}));});
  const client={socket,messages,call,ticket:ticket.ticket};sockets.push(client);return client;
 };
 try{
  assert.equal((await mf.dispatchFetch('http://local/v1/session',{method:'POST'})).status,401);
  const clients=[],rooms=[];
  // Avoid a synthetic global auth burst; room requests still share one live object.
  for(let i=1;i<=100;i++){const c=await connect(i);clients.push(c);rooms.push(await c.call('command',{op:'quick_join'}));assert.ok(rooms.at(-1).id,rooms.at(-1).error);}
  assert.equal(new Set(rooms.map(r=>r.id)).size,20);
  assert.equal((await clients[0].call('command',{op:'state',room_id:rooms[5].id})).error,'not_a_member');
  const responses=await Promise.all(clients.map((c,i)=>c.call('command',{op:'state',room_id:rooms[i].id})));
  assert.ok(responses.every(r=>r.members.length===5));
  await mf.unsafeEvictDurableObject('lakebound-test','LakeboundMatches',{name:'lakebound-v1',webSockets:'hibernate'});
  assert.equal((await clients[0].call('command',{op:'state',room_id:rooms[0].id})).members.length,5);
  const common={room_id:rooms[0].id,round_id:rooms[0].round_id};
  for(let i=0;i<5;i++)assert.ok((await clients[i].call('rtc',{op:'open',...common,session_id:id(i+1)})).peers);
  const before=clients[1].messages.length,outsider=clients[5].messages.length;
  await clients[0].call('rtc',{op:'send',...common,session_id:id(1),items:[{to:id(2),to_session:id(2),from:id(6),kind:'offer',data:'qa-sdp'}]});
  const received=clients[1].messages.slice(before).find(m=>m.type==='rtc_signal');assert.equal(received.message.from,id(1));assert.equal(clients[5].messages.slice(outsider).filter(m=>m.type==='rtc_signal').length,0);
  assert.equal((await clients[0].call('rtc',{op:'send',...common,session_id:id(1),items:[{to:id(2),to_session:id(2),kind:'pose',data:{}}]})).error,'invalid_rtc_payload');
  const again=await connect(1);assert.equal((await again.call('command',{op:'quick_join'})).id,rooms[0].id);
  const steal=await mf.dispatchFetch('http://local/v1/socket',{headers:{Upgrade:'websocket'}});steal.webSocket.accept();const closed=new Promise(resolve=>steal.webSocket.addEventListener('close',resolve));steal.webSocket.send(JSON.stringify({type:'auth',ticket:again.ticket}));await closed;
  // Closing only one member preserves a live room, including across hibernation.
  const closing=clients.slice(95,100);
  closing[0].socket.close();
  assert.equal((await closing[1].call('command',{op:'state',room_id:rooms[95].id})).id,rooms[95].id);
  const ended=closing.slice(1).map(c=>new Promise(resolve=>{c.socket.addEventListener('close',resolve,{once:true});c.socket.close();}));
  await Promise.all(ended);
  const returning=await connect(96);
  assert.equal((await returning.call('command',{op:'state',room_id:rooms[95].id})).error,'room_not_found');
  await mf.unsafeEvictDurableObject('lakebound-test','LakeboundMatches',{name:'lakebound-v1',webSockets:'hibernate'});
  assert.equal((await returning.call('command',{op:'state',room_id:rooms[95].id})).error,'room_not_found');
  assert.equal((await returning.call('command',{op:'join',code:rooms[95].code})).error,'room_not_found');
  assert.notEqual((await returning.call('command',{op:'quick_join'})).id,rooms[95].id);
  // Explicit leave also deletes the room durably without closing the socket.
  for(const c of [again,...clients.slice(1,5)])assert.ok((await c.call('command',{op:'leave',room_id:rooms[0].id})).id);
  await mf.unsafeEvictDurableObject('lakebound-test','LakeboundMatches',{name:'lakebound-v1',webSockets:'hibernate'});
  assert.equal((await again.call('command',{op:'state',room_id:rooms[0].id})).error,'room_not_found');
  console.log('EDGE SOCKET LOAD: 100 real authenticated test WebSockets / 20 rooms / 100 simultaneous snapshots; local workerd, not hosted capacity certification');
 }catch(error){console.error('EDGE SOCKET TEST FAILURE',error);throw error;}
 finally{for(const c of sockets)if(c.socket.readyState===1)c.socket.close();await mf.dispose();}
});
