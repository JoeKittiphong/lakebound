'use strict';
const $=id=>document.getElementById(id),links=new Map(),keys=new Set();
let me=null,config=null,polling=null,joining=false,sequence=0,sent=0,received=0,bytes=0,lastSend=0,lastFrame=performance.now(),lastStats=0,phase=0,position={x:500,y:160};
const params=new URLSearchParams(location.search);$('room').value=params.get('room')||'';$('relay').checked=params.get('relay')==='1';
async function api(route,data,signal){
 const r=await fetch('/api/'+route,{method:data===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(me?{Authorization:'Bearer '+me.token}:{})},...(data!==undefined?{body:JSON.stringify(data)}:{}),signal});
 const value=await r.json();if(!r.ok)throw Error(value.error||'request_failed');return value;
}
const fail=e=>{$('error').textContent=e.message||String(e);};
async function sendSignal(id,data){await api('signal',{to:id,...data});}
function link(id){
 if(links.has(id))return links.get(id);
 const pc=new RTCPeerConnection({iceServers:config.iceServers,iceTransportPolicy:$('relay').checked?'relay':'all'});
 const dc=pc.createDataChannel('lakebound-pose',{negotiated:true,id:0,ordered:false,maxRetransmits:0});
 const p={pc,dc,id,pending:[],seq:-1,pose:null,path:'connecting',rtt:null};links.set(id,p);
 pc.onicecandidate=e=>{if(e.candidate)sendSignal(id,{candidate:e.candidate.toJSON()}).catch(fail);};
 dc.onmessage=e=>{
  if(typeof e.data!=='string'||e.data.length>1024)return;
  let v;try{v=JSON.parse(e.data);}catch{return;}
  if(v.kind==='ping'&&Number.isFinite(v.at)){if(dc.readyState==='open')dc.send(JSON.stringify({kind:'pong',at:v.at}));return;}
  if(v.kind==='pong'&&Number.isFinite(v.at)){p.rtt=Math.max(0,performance.now()-v.at);return;}
  if(v.id!==id||!Array.isArray(v.p)||v.p.length!==3||!v.p.every(Number.isFinite)||!Number.isInteger(v.seq)||v.seq<=p.seq||v.p.some(x=>Math.abs(x)>100000))return;
  p.seq=v.seq;p.pose=v;received++;bytes+=e.data.length;
 };
 return p;
}
async function event(e){
 if(e.type==='peers'){
  for(const id of e.ids){if(id===me.id||links.has(id))continue;const p=link(id);if(me.id<id){await p.pc.setLocalDescription(await p.pc.createOffer());await sendSignal(id,{description:p.pc.localDescription.toJSON()});}}
 }else if(e.type==='left'){const p=links.get(e.id);if(p){p.pc.close();links.delete(e.id);}}
 else if(e.type==='signal'){
  const p=link(e.from);
  if(e.description){await p.pc.setRemoteDescription(e.description);for(const c of p.pending)await p.pc.addIceCandidate(c);p.pending=[];
   if(e.description.type==='offer'){await p.pc.setLocalDescription(await p.pc.createAnswer());await sendSignal(e.from,{description:p.pc.localDescription.toJSON()});}
  }else if(e.candidate){if(p.pc.remoteDescription)await p.pc.addIceCandidate(e.candidate);else if(p.pending.length<128)p.pending.push(e.candidate);}
 }
}
async function poll(signal){try{while(me&&!signal.aborted){for(const e of await api('events',undefined,signal)){if(signal.aborted)return;await event(e);}}}catch(e){if(e.name!=='AbortError'){fail(e);await leave();}}}
async function join(){
 if(me||joining)return;joining=true;$('error').textContent='';$('join').disabled=true;
 try{
  me=await api('join',{room:$('room').value.trim()});config=await api('ice');
  if($('relay').checked&&!config.turnConfigured)throw Error('ยังไม่ได้ตั้งค่า Cloudflare TURN · ทดลองเชื่อมตรงได้โดยปิด “บังคับ TURN”');
  $('room').value=me.room;$('room').disabled=true;$('relay').disabled=true;$('leave').disabled=false;
  $('status').textContent='ห้อง '+me.room+' · ผู้เล่น '+me.id.slice(0,6)+' · '+(config.turnConfigured?'TURN พร้อมใช้':'Direct/STUN — ยังไม่มี TURN');
  phase=parseInt(me.id.slice(0,4),16)/65536*Math.PI*2;polling=new AbortController();poll(polling.signal);
 }catch(e){fail(e);await leave();}finally{joining=false;if(!me)$('join').disabled=false;}
}
async function leave(){
 polling?.abort();for(const p of links.values())p.pc.close();links.clear();
 if(me){try{await api('leave',{});}catch{}me=null;}
 $('join').disabled=false;$('leave').disabled=true;$('room').disabled=false;$('relay').disabled=false;$('status').textContent='ออกจากห้องแล้ว';
}
$('join').onclick=join;$('leave').onclick=leave;
addEventListener('keydown',e=>{if(e.target.tagName==='INPUT')return;keys.add(e.key);if(e.key.startsWith('Arrow'))e.preventDefault();});addEventListener('keyup',e=>keys.delete(e.key));addEventListener('blur',()=>keys.clear());
$('world').onpointerdown=e=>{if($('auto').checked)return;const b=$('world').getBoundingClientRect();position={x:(e.clientX-b.left)/b.width*1000,y:(e.clientY-b.top)/b.height*320};};
async function stats(){
 const out=[];for(const p of links.values()){
  try{const all=await p.pc.getStats();let pair;all.forEach(v=>{if(v.type==='transport'&&v.selectedCandidatePairId)pair=all.get(v.selectedCandidatePairId);});if(!pair)all.forEach(v=>{if(v.type==='candidate-pair'&&v.state==='succeeded'&&v.nominated)pair=v;});
   if(pair){const local=all.get(pair.localCandidateId),remote=all.get(pair.remoteCandidateId);p.path=`${local?.candidateType||'?'} ↔ ${remote?.candidateType||'?'}`;}
   if(p.dc.readyState==='open')p.dc.send(JSON.stringify({kind:'ping',at:performance.now()}));
  }catch{}
  out.push(p.id.slice(0,6)+' · '+p.pc.connectionState+' · '+p.path);
 }
 if(me){try{const s=await api('status');out.push('Signaling messages: '+s.signalingMessages+' · DataChannel payload bytes received: '+bytes);$('serverposes').textContent=s.poseMessagesThroughServer;}catch(e){fail(e);}}
 $('paths').textContent=out.join('\n')||'ยังไม่มีผู้เล่นอีกฝั่ง';
 const times=[...links.values()].map(p=>p.rtt).filter(Number.isFinite);$('rtt').textContent=times.length?Math.round(Math.max(...times))+' ms':'—';
}
function frame(now){
 const dt=Math.min((now-lastFrame)/1000,0.05);lastFrame=now;
 if($('auto').checked){phase+=dt*.6;position={x:500+Math.cos(phase)*270,y:160+Math.sin(phase)*95};}
 else{position.x=Math.max(15,Math.min(985,position.x+((keys.has('ArrowRight')?1:0)-(keys.has('ArrowLeft')?1:0))*180*dt));position.y=Math.max(15,Math.min(305,position.y+((keys.has('ArrowDown')?1:0)-(keys.has('ArrowUp')?1:0))*180*dt));}
 if(me&&now-lastSend>=50){lastSend=now;const packet=JSON.stringify({id:me.id,p:[position.x,0,position.y],yaw:phase,speed:3,state:0,seq:++sequence});for(const p of links.values())if(p.dc.readyState==='open'&&p.dc.bufferedAmount<16384){p.dc.send(packet);sent++;}}
 const ctx=$('world').getContext('2d');ctx.clearRect(0,0,1000,320);ctx.strokeStyle='#34595a';for(let x=0;x<1000;x+=50){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,320);ctx.stroke();}
 function dot(x,y,label,color){ctx.fillStyle=color;ctx.beginPath();ctx.arc(x,y,12,0,Math.PI*2);ctx.fill();ctx.font='15px Segoe UI';ctx.fillText(label,x+18,y+5);}
 dot(position.x,position.y,'คุณ','#d5ed9a');for(const p of links.values())if(p.pose)dot(p.pose.p[0],p.pose.p[2],p.id.slice(0,6),'#7fd3ee');
 $('sent').textContent=sent;$('received').textContent=received;$('connected').textContent=[...links.values()].filter(p=>p.dc.readyState==='open').length;
 if(now-lastStats>=1500){lastStats=now;stats().catch(fail);}requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
