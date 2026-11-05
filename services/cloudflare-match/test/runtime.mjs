import {Miniflare,convertV4MiniflareOptions} from 'miniflare';
import {fileURLToPath} from 'node:url';
export function runtime(port=0){return new Miniflare(convertV4MiniflareOptions({
 name:'lakebound-test',
 modules:['worker.mjs','registry.mjs','species.mjs','social.mjs'].map(name=>({type:'ESModule',path:fileURLToPath(new URL('../src/'+name,import.meta.url))})),modulesRoot:fileURLToPath(new URL('../src/',import.meta.url)),compatibilityDate:'2026-11-03',host:'127.0.0.1',port,
 durableObjects:{MATCHES:{className:'LakeboundMatches',useSQLite:true}},
 bindings:{SUPABASE_URL:'https://identity.test',SUPABASE_PUBLISHABLE_KEY:'test-public-key',ENVIRONMENT:'test',MAX_PLAYERS:'100',MAX_ROOMS:'20',ACCEPTS_NEW:'true'},
 outboundService:request=>{
  if(new URL(request.url).origin!=='https://identity.test')return new Response('{}',{status:503});
  const match=/^Bearer qa\.([a-f0-9]{32})\.signature$/.exec(request.headers.get('Authorization')||'');
  return new Response(JSON.stringify(match?{id:match[1],name:'QA '+match[1].slice(-3),expires_at:Math.floor(Date.now()/1000)+3600}:{error:'google_login_required'}),{status:match?200:401,headers:{'Content-Type':'application/json'}});
 }
}));}
