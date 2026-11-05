class_name WebOAuth
extends RefCounted

# Local storage survives the external browser used by installed mobile PWAs.
# Only a short-lived PKCE verifier is stored here, never an access token.
const SCRIPT := """
(() => {
 const key = 'lakebound.oauth.pending.v1';
 const redirect = location.origin + location.pathname;
 const allowed = redirect === 'https://lakebound-zylaah.netlify.app/' ||
   redirect === 'https://lakebound-zylaah.netlify.app/index.html';
 return {
  redirect: () => allowed ? redirect : '',
  begin: (verifier, url) => {
   if (!allowed) return 'blocked';
   try {
    localStorage.setItem(key, JSON.stringify({verifier, redirect, started: Date.now()}));
    console.info('Lakebound OAuth: pending saved');
    // Let the bridge return before navigation can tear down the WebAssembly call.
    setTimeout(() => location.assign(url), 0);
    return 'ok';
   } catch (_) { try { localStorage.removeItem(key); } catch (_) {} return 'storage_error'; }
  },
  clear: () => { console.info('Lakebound OAuth: pending cleared'); try { localStorage.removeItem(key); } catch (_) {} },
  consume: () => {
   const url = new URL(location.href);
   if (!url.searchParams.has('code') && !url.searchParams.has('error')) return '{}';
   const callback = location.href;
   history.replaceState(null, '', location.pathname);
   try {
    const pending = JSON.parse(localStorage.getItem(key) || 'null');
    localStorage.removeItem(key);
    let reason = !allowed ? 'origin' : !pending ? 'missing_pending' :
      pending.redirect !== redirect ? 'redirect' :
      !/^[A-Za-z0-9_-]{43}$/.test(pending.verifier) ? 'verifier' :
      !Number.isFinite(pending.started) || Date.now()-pending.started < 0 || Date.now()-pending.started > 600000 ? 'expired' : '';
    if (reason) { console.warn('Lakebound OAuth callback rejected: '+reason); return JSON.stringify({error:true}); }
    return JSON.stringify({verifier:pending.verifier, redirect, callback});
   } catch (_) { return JSON.stringify({error:true}); }
  }
 };
})()
"""

static func redirect() -> String:
 return str(JavaScriptBridge.eval(SCRIPT+".redirect()"))

static func begin(verifier: String, url: String) -> bool:
 return str(JavaScriptBridge.eval(SCRIPT+".begin("+JSON.stringify(verifier)+","+JSON.stringify(url)+")"))=="ok"

static func clear() -> void:
 JavaScriptBridge.eval(SCRIPT+".clear()")

static func consume() -> Dictionary:
 var result: Variant=JavaScriptBridge.eval(SCRIPT+".consume()")
 if not result is String: return {}
 var text := str(result)
 if text.is_empty(): return {}
 var value: Variant=JSON.parse_string(text)
 return value if value is Dictionary else {}
