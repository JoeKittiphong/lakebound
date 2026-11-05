const {test}=require('node:test'),assert=require('node:assert/strict');
const {createLab,iceConfig}=require('./server.cjs');
test('TURN broker keeps permanent token server-side and asks for expiring credentials',async()=>{
 let calls=0;
 const fake=async(url,options)=>{calls++;assert.equal(url,'https://rtc.live.cloudflare.com/v1/turn/keys/test-key/credentials/generate-ice-servers');assert.equal(options.headers.Authorization,'Bearer permanent-private-test');assert.equal(JSON.parse(options.body).ttl,3600);return {ok:true,json:async()=>({iceServers:[{urls:['turn:turn.cloudflare.com:3478?transport=udp'],username:'temporary',credential:'short-lived'}]})};};
 const result=await iceConfig({LAKEBOUND_CF_TURN_KEY_ID:'test-key',LAKEBOUND_CF_TURN_API_TOKEN:'permanent-private-test'},fake);
 assert.equal(calls,1);assert.equal(result.turnConfigured,true);assert.ok(!JSON.stringify(result).includes('permanent-private-test'));
 await assert.rejects(iceConfig({LAKEBOUND_CF_TURN_KEY_ID:'test'},fake),/turn_config_incomplete/);
 assert.equal((await iceConfig({},fake)).turnConfigured,false);
 await assert.rejects(iceConfig({LAKEBOUND_CF_TURN_KEY_ID:'test',LAKEBOUND_CF_TURN_API_TOKEN:'x'},async()=>({ok:false})),/turn_credentials_failed/);
});
test('local signaling admits five peers, isolates rooms, and refuses pose traffic',async()=>{
 const server=createLab({env:{}});await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 const people=[];
 async function api(route,data,who,extra={}){const r=await fetch(base+'/api/'+route,{method:data===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(who?{Authorization:'Bearer '+who.token}:{}),...extra},...(data===undefined?{}:{body:JSON.stringify(data)})});return {status:r.status,value:await r.json()};}
 try{
  assert.equal((await api('join',{room:'abcde'})).status,400);
  assert.equal((await api('join',{room:'12345'},null,{Origin:'https://untrusted.invalid'})).status,403);
  assert.equal((await api('ice')).status,401);
  const a=(await api('join',{room:'12345'})).value;people.push(a);
  const b=(await api('join',{room:'12345'})).value;people.push(b);
  const c=(await api('join',{room:'54321'})).value;people.push(c);
  assert.notEqual(a.token,b.token);assert.match(a.id,/^[a-f0-9]{32}$/);
  assert.equal((await api('signal',{to:c.id,description:{type:'offer',sdp:'test'}},a)).status,400);
  assert.equal((await api('signal',{to:b.id,pose:[1,2,3]},a)).status,400);
  assert.equal((await api('signal',{to:b.id},a)).status,400);
  assert.equal((await api('signal',{to:b.id,description:{type:'offer',sdp:'test'}},a)).status,200);
  const events=(await api('events',undefined,b)).value;
  assert.ok(events.some(e=>e.type==='signal'&&e.from===a.id&&e.description.sdp==='test'));
  assert.equal((await api('ice',undefined,a)).value.turnConfigured,false);
  for(let i=0;i<3;i++)people.push((await api('join',{room:'12345'})).value);
  assert.equal((await api('join',{room:'12345'})).value.error,'room_full');
  const stats=(await api('status',undefined,a)).value;assert.equal(stats.peers,5);assert.equal(stats.signalingMessages,1);assert.equal(stats.poseMessagesThroughServer,0);
  assert.equal((await api('leave',{},b)).status,200);
  assert.equal((await api('status',undefined,b)).status,401);
  people.push((await api('join',{room:'12345'})).value);
 }finally{for(const p of people)await api('leave',{},p);await new Promise(r=>server.close(r));}
});
