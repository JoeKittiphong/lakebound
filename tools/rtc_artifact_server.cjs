// Local UI for transferring reviewed deployment source into dashboard editors.
// Fixed allowlist only; never serves credential files or arbitrary paths.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const files={migration:'services/supabase/migrations/202611030015_match_webrtc.sql',capacity:'services/supabase/migrations/202611030016_match_capacity.sql',edge_identity:'services/supabase/migrations/202611030017_edge_identity.sql',function:'services/supabase/functions/lakebound-turn/index.ts'};
http.createServer((req,res)=>{const key=req.url.slice(1),file=files[key];if(!file||req.headers.host!=='127.0.0.1:43842'){res.writeHead(404);return res.end();}const source=fs.readFileSync(path.join(root,file),'utf8');res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end('<h1>Reviewed Lakebound deployment source</h1><label>Source<textarea readonly style="width:100%;height:80vh">'+source.replaceAll('&','&amp;').replaceAll('<','&lt;')+'</textarea></label>');}).listen(43842,'127.0.0.1',()=>console.log('Deployment source UI on http://127.0.0.1:43842'));
