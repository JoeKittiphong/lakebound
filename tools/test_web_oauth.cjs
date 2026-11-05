const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('features/auth/web_oauth.gd','utf8').match(/const SCRIPT := """([\s\S]*?)"""/)[1];
function browser(href='https://lakebound-zylaah.netlify.app/') {
 const values=new Map(),tasks=[]; const location=new URL(href);
 location.assign=url=>{location.assigned=url;};
 const context={URL,Date,setTimeout:fn=>tasks.push(fn),location,history:{replaceState:(_,__,path)=>{context.cleaned=path;}},localStorage:{setItem:(k,v)=>values.set(k,v),getItem:k=>values.get(k),removeItem:k=>values.delete(k)}};
 return {api:vm.runInNewContext(source,context),context,values,location,flush:()=>tasks.splice(0).forEach(fn=>fn())};
}
const verifier='a'.repeat(43),key='lakebound.oauth.pending.v1';
let b=browser();assert.equal(b.api.redirect(),'https://lakebound-zylaah.netlify.app/');
assert.equal(b.api.begin(verifier,'https://provider.example/'),'ok');
assert.equal(b.location.assigned,undefined,'bridge returns before browser leaves the game');b.flush();
assert.equal(b.location.assigned,'https://provider.example/');
assert.equal(JSON.parse(b.values.get(key)).verifier,verifier);
// Reload after provider redirect, retaining only origin storage.
let returned=browser('https://lakebound-zylaah.netlify.app/?code=valid-code');
returned.values.set(key,b.values.get(key));
let result=JSON.parse(returned.api.consume());assert.equal(result.verifier,verifier);assert.equal(result.callback,returned.location.href);
assert.equal(returned.context.cleaned,'/');assert.equal(returned.values.size,0);
assert.equal(JSON.parse(returned.api.consume()).error,true);
for(const pending of [null,{verifier,redirect:'https://evil.example/',started:Date.now()}, {verifier,redirect:b.api.redirect(),started:Date.now()-600001}, {verifier:'bad',redirect:b.api.redirect(),started:Date.now()}]) {
 returned=browser('https://lakebound-zylaah.netlify.app/?code=valid-code');returned.values.set(key,JSON.stringify(pending));
 assert.equal(JSON.parse(returned.api.consume()).error,true);
}
b=browser('https://evil.example/');assert.equal(b.api.redirect(),'');assert.equal(b.api.begin(verifier,'https://provider.example/'),'blocked');
b=browser();assert.equal(b.api.consume(),'{}');b.api.begin(verifier,'https://provider.example/');b.api.clear();assert.equal(b.values.size,0);
b=browser('https://lakebound-zylaah.netlify.app/?error=access_denied');assert.equal(JSON.parse(b.api.consume()).error,true);assert.equal(b.context.cleaned,'/');
console.log('PASS: web OAuth storage, navigation, reload, one-time consumption, expiry, origin, cancellation and URL cleanup');
