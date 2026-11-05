// Local-only signaling and short-lived TURN credential broker. No game state/storage.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const {randomBytes,randomInt}=require('node:crypto');
async function iceConfig(env=process.env,fetcher=fetch){
 const id=env.LAKEBOUND_CF_TURN_KEY_ID,token=env.LAKEBOUND_CF_TURN_API_TOKEN;
 if(!id&&!token)return {iceServers:[{urls:['stun:stun.cloudflare.com:3478']}],turnConfigured:false};
 if(!id||!token||!/^[a-zA-Z0-9_-]{1,128}$/.test(id))throw Error('turn_config_incomplete');
 const r=await fetcher(`https://rtc.live.cloudflare.com/v1/turn/keys/${id}/credentials/generate-ice-servers`,{
  method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({ttl:3600}),signal:AbortSignal.timeout(10000)});
 if(!r.ok)throw Error('turn_credentials_failed');
 const data=await r.json();
 if(!Array.isArray(data.iceServers)||!data.iceServers.some(s=>[].concat(s.urls||[]).some(u=>/^turns?:/.test(u))))throw Error('invalid_turn_response');
 return {iceServers:data.iceServers,turnConfigured:true,expiresIn:3600};
}
function createLab({env=process.env,fetcher=fetch}={}){
 const rooms=new Map(),members=new Map();let signals=0;
 const json=(res,status,data)=>{if(!res.writableEnded){res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));}};
 function push(m,e){if(m.waiter){const res=m.waiter;m.waiter=null;clearTimeout(m.timer);json(res,200,[e]);}else if(m.queue.length<256)m.queue.push(e);else remove(m);}
 function broadcast(room,e){for(const m of room.values())push(m,e);}
 function remove(m){if(!members.has(m.token))return;members.delete(m.token);const room=rooms.get(m.room);room.delete(m.id);clearTimeout(m.timer);if(m.waiter)json(m.waiter,200,[]);if(!room.size)rooms.delete(m.room);else broadcast(room,{type:'left',id:m.id});}
 async function body(req){let text='';for await(const part of req){text+=part;if(Buffer.byteLength(text)>65536)throw Error('payload_too_large');}return JSON.parse(text||'{}');}
 const server=http.createServer(async(req,res)=>{
  try{
   // Prevent DNS rebinding and cross-site access to this local credential broker.
   const host=req.headers.host||'';
   if(!/^(127\.0\.0\.1|localhost):\d+$/.test(host))return json(res,403,{error:'host_denied'});
   if(req.headers.origin&&req.headers.origin!==`http://${host}`)return json(res,403,{error:'origin_denied'});
   const url=new URL(req.url,`http://${host}`);
   if(req.method==='GET'&&(url.pathname==='/'||url.pathname==='/lab.js')){
    const name=url.pathname==='/'?'index.html':'lab.js';res.writeHead(200,{'Content-Type':name.endsWith('.html')?'text/html; charset=utf-8':'text/javascript; charset=utf-8','Cache-Control':'no-store','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'"});return res.end(fs.readFileSync(path.join(__dirname,name)));
   }
   if(req.method==='POST'&&url.pathname==='/api/join'){
    const data=await body(req);let code=data.room;
    if(code===undefined||code===''){do{code=String(randomInt(100000)).padStart(5,'0');}while(rooms.has(code));}
    if(typeof code!=='string'||!/^\d{5}$/.test(code))return json(res,400,{error:'five_digit_room_required'});
    if(members.size>=50||(!rooms.has(code)&&rooms.size>=10))return json(res,429,{error:'lab_capacity'});
    const room=rooms.get(code)||new Map();if(room.size>=5)return json(res,409,{error:'room_full'});
    const m={id:randomBytes(16).toString('hex'),token:randomBytes(32).toString('hex'),room:code,queue:[],seen:Date.now(),window:Date.now(),count:0};
    room.set(m.id,m);rooms.set(code,room);members.set(m.token,m);
    json(res,200,{id:m.id,token:m.token,room:code});broadcast(room,{type:'peers',ids:[...room.keys()]});return;
   }
   const m=members.get((req.headers.authorization||'').replace(/^Bearer /,''));
   if(!m)return json(res,401,{error:'join_required'});m.seen=Date.now();
   if(Date.now()-m.window>=1000){m.window=Date.now();m.count=0;}if(++m.count>60)return json(res,429,{error:'signaling_rate_limited'});
   if(req.method==='GET'&&url.pathname==='/api/ice'){
    if(!m.icePromise)m.icePromise=iceConfig(env,fetcher).catch(e=>{m.icePromise=null;throw e;});
    return json(res,200,await m.icePromise);
   }
   if(req.method==='GET'&&url.pathname==='/api/events'){
    if(m.waiter)return json(res,409,{error:'poll_already_waiting'});
    if(m.queue.length)return json(res,200,m.queue.splice(0));m.waiter=res;m.timer=setTimeout(()=>{m.waiter=null;json(res,200,[]);},15000);
    res.on('close',()=>{if(m.waiter===res){m.waiter=null;clearTimeout(m.timer);}});return;
   }
   if(req.method==='POST'&&url.pathname==='/api/signal'){
    const data=await body(req),dest=rooms.get(m.room).get(data.to),d=data.description,c=data.candidate;
    if(!dest||dest===m)return json(res,400,{error:'unknown_peer'});
    const validDescription=!!(d&&['offer','answer'].includes(d.type)&&typeof d.sdp==='string'&&d.sdp.length<60000);
    const validCandidate=!!(c&&typeof c.candidate==='string'&&c.candidate.length<2048&&(typeof c.sdpMid==='string'||c.sdpMid===null)&&Number.isInteger(c.sdpMLineIndex)&&c.sdpMLineIndex>=0);
    if(!(validDescription!==!!validCandidate)||Object.keys(data).some(k=>!['to','description','candidate'].includes(k)))return json(res,400,{error:'signaling_only'});
    signals++;push(dest,{type:'signal',from:m.id,...(validDescription?{description:d}:{candidate:c})});return json(res,200,{ok:true});
   }
   if(req.method==='GET'&&url.pathname==='/api/status')return json(res,200,{peers:rooms.get(m.room).size,signalingMessages:signals,poseMessagesThroughServer:0});
   if(req.method==='POST'&&url.pathname==='/api/leave'){remove(m);return json(res,200,{ok:true});}
   json(res,404,{error:'not_found'});
  }catch(e){json(res,400,{error:['turn_config_incomplete','turn_credentials_failed','invalid_turn_response','payload_too_large'].includes(e.message)?e.message:'request_failed'});}
 });
 const sweep=setInterval(()=>{for(const m of members.values())if(Date.now()-m.seen>45000)remove(m);},10000);sweep.unref();
 server.on('close',()=>{clearInterval(sweep);for(const m of [...members.values()])remove(m);});
 return server;
}
module.exports={createLab,iceConfig};
if(require.main===module){const port=Number(process.env.LAKEBOUND_RTC_PORT||43840);const env={...process.env,...require('./secret-store.cjs').load()};createLab({env}).listen(port,'127.0.0.1',()=>console.log(`WebRTC lab: http://127.0.0.1:${port} (local-only; TURN ${env.LAKEBOUND_CF_TURN_KEY_ID?'configured':'not configured'})`));}
