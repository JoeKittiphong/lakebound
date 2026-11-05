// Permanent Cloudflare secrets stay in Edge Function secrets, never in the game.
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS","Cache-Control":"no-store"};
const reply=(status:number,data:unknown)=>new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json"}});
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response(null,{headers:cors});
 if(req.method!=="POST")return reply(405,{error:"method_not_allowed"});
 try{
  const jwt=req.headers.get("Authorization")||"";
  if(!jwt.startsWith("Bearer "))return reply(401,{error:"google_login_required"});
  const text=await req.text();if(text.length>4096)return reply(400,{error:"invalid_payload"});const body=JSON.parse(text);
  const url=Deno.env.get("SUPABASE_URL")!,publicKey=Deno.env.get("LAKEBOUND_PUBLISHABLE_KEY")!,serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const keyId=Deno.env.get("LAKEBOUND_CF_TURN_KEY_ID"),keyToken=Deno.env.get("LAKEBOUND_CF_TURN_API_TOKEN");
  if(!keyId||!keyToken||!publicKey)return reply(503,{error:"turn_not_configured"});
  const fetchJson=async(endpoint:string,headers:Record<string,string>,payload?:unknown)=>{
   const r=await fetch(endpoint,{method:payload===undefined?"GET":"POST",headers:{...headers,"Content-Type":"application/json"},...(payload===undefined?{}:{body:JSON.stringify(payload)}),signal:AbortSignal.timeout(10000)});
   if(!r.ok)throw Error("upstream_failed");return await r.json();
  };
  const user=await fetchJson(url+"/auth/v1/user",{Authorization:jwt,apikey:publicKey});
  if(user.app_metadata?.provider!=="google"||user.is_anonymous)return reply(401,{error:"google_login_required"});
  const room=await fetchJson(url+"/rest/v1/rpc/lakebound_matches",{Authorization:jwt,apikey:publicKey},{payload:{op:"state",player_id:body.player_id,player_name:body.player_name,token:body.token,room_id:body.room_id}});
  if(room.error)return reply(403,{error:room.error});
  if(room.round_id!==body.round_id||!["lobby","loading","countdown","running"].includes(room.phase)||!room.members?.some((m:any)=>m.id===body.player_id&&!m.departed))return reply(403,{error:"not_a_member"});
  const cache=(data:unknown)=>fetchJson(url+"/rest/v1/rpc/lakebound_turn_cache",{Authorization:"Bearer "+serviceKey,apikey:serviceKey},{payload:{auth_id:user.id,room_id:room.id,round_id:room.round_id,...data as object}});
  const cached=await cache({op:"reserve"});if(cached.error)return reply(429,{error:cached.error});if(cached.iceServers)return reply(200,cached);
  const cf=await fetchJson("https://rtc.live.cloudflare.com/v1/turn/keys/"+keyId+"/credentials/generate-ice-servers",{Authorization:"Bearer "+keyToken},{ttl:3600});
  if(!Array.isArray(cf.iceServers))throw Error("invalid_turn_response");
  const result=await cache({op:"commit",ticket:cached.ticket,iceServers:cf.iceServers});
  return reply(result.error?503:200,result);
 }catch{return reply(503,{error:"turn_temporarily_unavailable"});}
});
