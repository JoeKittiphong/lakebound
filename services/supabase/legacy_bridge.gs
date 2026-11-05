// Compatibility endpoint for already-installed Sheets clients.
// build_bridge.py adds LB_SUPABASE using the public config in online.cfg.
// No credentials or player payloads are logged or placed in URLs.
function doGet(e) {
  const p = e && e.parameter || {};
  const query = {scope:p.scope || 'all',limit:Number(p.limit || 10)};
  if (p.version) query.version = p.version;
  return supabaseProxy_({query});
}
function doPost(e) {
  const body = e && e.postData && e.postData.contents;
  if (typeof body !== 'string' || body.length > 100000) return json_({error:'invalid_payload'});
  let payload;
  try { payload = JSON.parse(body); } catch (_) { return json_({error:'invalid_payload'}); }
  return supabaseProxy_(payload);
}
function supabaseProxy_(payload) {
  try {
    const response = UrlFetchApp.fetch(LB_SUPABASE.url, {
      method:'post',contentType:'application/json',
      headers:{apikey:LB_SUPABASE.key},
      payload:JSON.stringify({payload}),muteHttpExceptions:true,followRedirects:false
    });
    const code=response.getResponseCode();
    if(code===200) return json_(JSON.parse(response.getContentText()));
    if(code===401 || code===403) return json_({error:'invalid_credentials'});
    return json_({error:'busy_retry',retry_after:3});
  } catch (_) {
    return json_({error:'busy_retry',retry_after:3});
  }
}
// Manual read-only health check. Throws so editor logs show configuration errors.
function checkSupabaseConnection() {
  const response=UrlFetchApp.fetch(LB_SUPABASE.url, {
    method:'post',contentType:'application/json',headers:{apikey:LB_SUPABASE.key},
    payload:JSON.stringify({payload:{query:{scope:'all',limit:10}}}),
    muteHttpExceptions:true,followRedirects:false
  });
  const data=JSON.parse(response.getContentText());
  if(response.getResponseCode()!==200 || data.schema!==3)
    throw new Error('Supabase health HTTP '+response.getResponseCode()+': '+String(data.error || data.message || 'unexpected schema'));
  console.log('Supabase connected: '+data.rows.length+' rows');
}
