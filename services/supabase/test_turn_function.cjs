const {test}=require('node:test'),assert=require('node:assert/strict'),{pathToFileURL}=require('node:url'),path=require('node:path');
let handler;const env={SUPABASE_URL:'https://test.supabase.co',LAKEBOUND_PUBLISHABLE_KEY:'public',SUPABASE_SERVICE_ROLE_KEY:'server-role',LAKEBOUND_CF_TURN_KEY_ID:'key-id',LAKEBOUND_CF_TURN_API_TOKEN:'private-turn'};
global.Deno={env:{get:k=>env[k]},serve:fn=>{handler=fn;}};
const ice=[{urls:['turn:turn.cloudflare.com:3478'],username:'short',credential:'temporary'}];
const body={player_id:'a'.repeat(32),player_name:'QA',token:'profile-proof',room_id:'room',round_id:'round'};
const req=(data=body,auth=true)=>new Request('https://test/lakebound-turn',{method:'POST',headers:auth?{Authorization:'Bearer user-jwt'}:{},body:JSON.stringify(data)});
test('Edge Function authorizes Google room members and never returns permanent tokens',async()=>{
 await import(pathToFileURL(path.join(__dirname,'functions/lakebound-turn/index.ts')).href);
 assert.equal((await handler(req(body,false))).status,401);
 let cfCalls=0,cached=false;
 global.fetch=async(url,options)=>{
  const send=data=>new Response(JSON.stringify(data),{status:200});
  if(url.endsWith('/auth/v1/user'))return send({id:'google-user',app_metadata:{provider:'google'}});
  if(url.endsWith('/lakebound_matches')){assert.equal(JSON.parse(options.body).payload.player_name,'QA');return send({id:'room',round_id:'round',phase:'running',members:[{id:body.player_id,departed:false}]});}
  if(url.endsWith('/lakebound_turn_cache')){assert.equal(options.headers.Authorization,'Bearer server-role');const p=JSON.parse(options.body).payload;if(p.op==='reserve')return send(cached?{iceServers:ice,expiresIn:3300}:{ticket:'ticket'});assert.equal(p.ticket,'ticket');cached=true;return send({iceServers:p.iceServers,expiresIn:3300});}
  assert.ok(url.startsWith('https://rtc.live.cloudflare.com/'));assert.equal(options.headers.Authorization,'Bearer private-turn');assert.equal(JSON.parse(options.body).ttl,3600);cfCalls++;return send({iceServers:ice});
 };
 const first=await handler(req());assert.equal(first.status,200);const text=await first.text();assert.ok(!text.includes('private-turn')&&!text.includes('server-role'));assert.equal(cfCalls,1);
 assert.equal((await handler(req())).status,200);assert.equal(cfCalls,1);
 assert.equal((await handler(req({...body,round_id:'old'}))).status,403);
 global.fetch=async()=>new Response(JSON.stringify({id:'x',app_metadata:{provider:'email'}}));assert.equal((await handler(req())).status,401);
 delete env.LAKEBOUND_CF_TURN_API_TOKEN;assert.equal((await handler(req())).status,503);env.LAKEBOUND_CF_TURN_API_TOKEN='private-turn';
 assert.equal((await handler(new Request('https://test',{method:'OPTIONS'}))).status,200);
});
