const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
let captured,code=200,value={schema:3,version:'v',rows:[]},calls=0;
const context={LB_SUPABASE:{url:'https://example.supabase.co/rest/v1/rpc/lakebound_rankings',key:'sb_publishable_test'},json_:x=>x,
 UrlFetchApp:{fetch:(url,options)=>{calls++;captured={url,...options};return{getResponseCode:()=>code,getContentText:()=>JSON.stringify(value)}}}};
vm.createContext(context);vm.runInContext(fs.readFileSync(__dirname+'/legacy_bridge.gs','utf8'),context);
assert.equal(context.doGet({parameter:{scope:'river',limit:'50',version:'old'}}).schema,3);
assert.deepEqual(JSON.parse(captured.payload),{payload:{query:{scope:'river',limit:50,version:'old'}}});
assert.equal(captured.followRedirects,false);
const p={player_id:'a'.repeat(32),token:'b'.repeat(64),catches:[]};
context.doPost({postData:{contents:JSON.stringify(p)}});
assert.deepEqual(JSON.parse(captured.payload),{payload:p});
assert.ok(!captured.url.includes(p.token));
const before=calls;assert.equal(context.doPost({postData:{contents:'broken'}}).error,'invalid_payload');assert.equal(calls,before);
code=429;assert.equal(context.doGet({}).error,'busy_retry');
code=403;assert.equal(context.doGet({}).error,'invalid_credentials');
console.log('BRIDGE RESULT: public read, private POST, no redirect, validation and error mapping passed');
