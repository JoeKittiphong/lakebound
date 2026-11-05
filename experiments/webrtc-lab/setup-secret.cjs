const http=require('node:http'),store=require('./secret-store.cjs');
const server=http.createServer(async(req,res)=>{
 const host=req.headers.host;if(host!=='127.0.0.1:43841'||(req.headers.origin&&req.headers.origin!=='http://'+host)){res.writeHead(403);return res.end();}
 res.setHeader('Cache-Control','no-store');
 if(req.method==='GET'&&req.url==='/'){res.setHeader('Content-Type','text/html; charset=utf-8');return res.end('<title>Lakebound TURN setup</title><h1>Store TURN credentials locally</h1><p>Encrypted with Windows DPAPI. No plaintext file or console logging.</p><form method="post"><label>TURN Key ID <input name="id" autocomplete="off"></label><br><label>TURN API Token <input name="token" type="password" autocomplete="off"></label><br><button>Store encrypted credentials</button></form>');}
 if(req.method==='POST'&&req.url==='/'){let body='';for await(const chunk of req){body+=chunk;if(body.length>2048){res.writeHead(413);return res.end();}}try{const data=new URLSearchParams(body);store.save(data.get('id')||'',data.get('token')||'');res.setHeader('Content-Type','text/html');res.end('<h1>TURN credentials stored encrypted</h1><p>You may close this setup page.</p>');setTimeout(()=>server.close(),500);}catch{res.writeHead(400);res.end('Unable to store credentials; no credentials logged.');}return;}
 res.writeHead(404);res.end();
});server.listen(43841,'127.0.0.1',()=>console.log('TURN setup ready on http://127.0.0.1:43841'));
