extends Node
signal changed
signal authenticated
var enabled := true
var busy := false
var waiting := false
var restoring := false
var status := "เข้าสู่ระบบเพื่อแข่งขันกับเพื่อน"
var email := ""
var user_id := ""
var account_ready := false
var needs_name := false
var access_token := ""
var refresh_token := ""
var expires_at := 0.0
var base_url := ""
var api_key := ""
var _verifier := ""
var _redirect := ""
var _started_at := 0
var _listener: TCPServer
var _peer: StreamPeerTCP
var _incoming := ""
var _android_bridge: Object
var _http_busy := false
var _refreshing := false
var _generation := 0
var _offline_chosen := false
@onready var request: HTTPRequest = $Request

func _ready() -> void:
 # Fetch already decompresses HTTP responses in browsers.
 if OS.has_feature("web"): request.accept_gzip=false
 enabled=OS.get_environment("LAKEBOUND_AUTH")!="0"
 var config := ConfigFile.new()
 if config.load("res://online.cfg")==OK:
  var url := str(config.get_value("supabase","url",""))
  if SupabaseConnectionSettings.valid_url(url): base_url=url.get_slice("/rest/",0)
  api_key=str(config.get_value("supabase","publishable_key",""))
 if not enabled: return
 _switch_profile("offline",{})
 if OS.has_feature("web") and _restore_web_callback(): return
 if OS.get_name()=="Android" and _restore_pending(): return
 var saved := ConfigFile.new()
 if saved.load("user://google_session_v1.cfg")==OK:
  refresh_token=str(saved.get_value("session","refresh",""))
 if not refresh_token.is_empty():
  restoring=true
  _restore.call_deferred()

func signed_in() -> bool:
 return account_ready and not needs_name and not user_id.is_empty() and not access_token.is_empty()

func _automatic_name(identity: Dictionary) -> bool:
 return str(identity.get("name","")) in ["", "นักตกปลา "+str(identity.get("id","")).left(6)]

func begin_google() -> void:
 if busy or not enabled: return
 if base_url.is_empty() or api_key.is_empty(): _error("ยังไม่ได้ตั้งค่าบริการเข้าสู่ระบบ"); return
 _close_listener()
 _generation+=1
 _verifier=OAuthPKCE.verifier()
 if OS.get_name()=="Android":
  var wrapper: Object=Engine.get_singleton("JavaClassWrapper")
  _android_bridge=wrapper.wrap("com.godot.game.LakeboundAuthBridge") if wrapper!=null else null
  if _android_bridge==null or wrapper.get_exception()!=null:
   _error("แอปรุ่นนี้ยังไม่รองรับการกลับจาก Google · กรุณาอัปเดตแอป"); return
  _redirect="com.zylaah.lakebound://auth/callback"
 elif OS.has_feature("web"):
  _redirect=WebOAuth.redirect()
  if _redirect.is_empty(): _error("เข้าสู่ระบบผ่านเว็บไซต์ Lakebound หลักเท่านั้น"); return
 else:
  _listener=TCPServer.new()
  if _listener.listen(43827,"127.0.0.1")!=OK: _error("เปิดการเชื่อมต่อกลับเข้าเกมไม่ได้ · ปิดหน้าล็อกอินอื่นแล้วลองใหม่"); return
  _redirect="http://127.0.0.1:43827/auth/callback"
 busy=true
 waiting=true
 _started_at=Time.get_ticks_msec()
 _save_pending()
 status="เลือกบัญชี Google ในเบราว์เซอร์ แล้วกลับเข้าเกม"
 changed.emit()
 var url := base_url+"/auth/v1/authorize?provider=google&redirect_to="+_redirect.uri_encode()+"&code_challenge="+OAuthPKCE.challenge(_verifier)+"&code_challenge_method=s256&prompt=select_account"
 if OS.has_feature("web"):
  if not WebOAuth.begin(_verifier,url): _error("เปิด Google ไม่ได้ · อนุญาตพื้นที่จัดเก็บของเว็บแล้วลองใหม่")
 elif OS.shell_open(url)!=OK: _error("เปิดเบราว์เซอร์ไม่ได้ · ลองอีกครั้ง")

func _restore_web_callback() -> bool:
 var pending := WebOAuth.consume()
 if pending.is_empty(): return false
 if pending.get("error",false):
  _error("การเข้าสู่ระบบหมดอายุหรือถูกยกเลิก · ลองใหม่อีกครั้ง")
  return true
 _verifier=str(pending.verifier)
 _redirect=str(pending.redirect)
 busy=true
 waiting=true
 restoring=true
 _started_at=Time.get_ticks_msec()
 accept_callback.call_deferred(str(pending.callback))
 return true

func _process(_delta: float) -> void:
 if not enabled: return
 if waiting:
  if Time.get_ticks_msec()-_started_at>180000: cancel_login(); status="หมดเวลารอ Google · ลองเข้าสู่ระบบอีกครั้ง"; changed.emit(); return
  if _android_bridge!=null:
   var callback := str(_android_bridge.consumeCallback())
   if not callback.is_empty(): accept_callback(callback)
  if _listener!=null:
   if _peer==null and _listener.is_connection_available(): _peer=_listener.take_connection(); _incoming=""
   if _peer!=null:
    _peer.poll()
    if _peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:
     var count := _peer.get_available_bytes()
     if count>0: _incoming+=_peer.get_utf8_string(count)
     if _incoming.length()>8192: _peer.disconnect_from_host(); _peer=null
     elif _incoming.contains("\r\n\r\n"):
      var target := _incoming.get_slice("\r\n",0).get_slice(" ",1)
      var callback := "http://127.0.0.1:43827"+target
      var valid := not OAuthPKCE.callback_code(callback,_redirect).is_empty()
      var body := "Login received. You may return to Lakebound." if valid else "Invalid callback. Return to Lakebound and try again."
      _peer.put_data(("HTTP/1.1 "+("200 OK" if valid else "400 Bad Request")+"\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: "+str(body.to_utf8_buffer().size())+"\r\n\r\n"+body).to_utf8_buffer())
      _peer.disconnect_from_host(); _peer=null
      if valid: accept_callback(callback)

func accept_callback(url: String) -> void:
 if not waiting or _verifier.is_empty(): return
 var code := OAuthPKCE.callback_code(url,_redirect)
 if code.is_empty(): _error("Google ส่งผลการเข้าสู่ระบบไม่สำเร็จ · ลองอีกครั้ง"); return
 waiting=false
 _close_listener()
 _exchange(code)

func _exchange(code: String) -> void:
 var generation := _generation
 status="กำลังยืนยันบัญชี Google…"
 changed.emit()
 var result := await _http("/auth/v1/token?grant_type=pkce",{"auth_code":code,"code_verifier":_verifier})
 _verifier=""
 _clear_pending()
 if generation!=_generation: return
 if not _accept_session(result): _error("เข้าสู่ระบบไม่สำเร็จ · ตรวจการตั้งค่า Google หรือเริ่มใหม่"); return
 await _load_account(generation)

func _restore() -> void:
 busy=true
 status="กำลังเชื่อมบัญชีเดิม…"
 changed.emit()
 if not await ensure_session():
  restoring=false
  _error("ยังเชื่อมบัญชีไม่ได้ · เข้าสู่ระบบใหม่หรือเล่นออฟไลน์"); return
 await _load_account(_generation)

func ensure_session() -> bool:
 if expires_at>Time.get_unix_time_from_system()+60 and not access_token.is_empty(): return true
 if _refreshing:
  while _refreshing: await get_tree().process_frame
  return not access_token.is_empty() and expires_at>Time.get_unix_time_from_system()+60
 if refresh_token.is_empty(): return false
 _refreshing=true
 var generation := _generation
 var result := await _http("/auth/v1/token?grant_type=refresh_token",{"refresh_token":refresh_token})
 _refreshing=false
 if generation!=_generation: return false
 if result.get("error")=="network_error": return false
 if not _accept_session(result):
  access_token=""; refresh_token=""; expires_at=0
  _save_session()
  return false
 return true

func _accept_session(value: Dictionary) -> bool:
 if not value.get("access_token") is String or not value.get("refresh_token") is String or not value.get("user") is Dictionary: return false
 var user: Dictionary=value.user
 if not user.get("id") is String or user.id.length()!=36 or user.get("is_anonymous",false): return false
 if user.get("app_metadata",{}).get("provider","")!="google": return false
 if not user.get("email") is String: return false
 access_token=value.access_token
 refresh_token=value.refresh_token
 user_id=user.id
 email=user.email
 expires_at=Time.get_unix_time_from_system()+clampf(float(value.get("expires_in",3600)),60,86400)
 _save_session()
 return true

func _load_account(generation: int) -> void:
 var result := await _http("/rest/v1/rpc/lakebound_account",{"payload":{}},true)
 if generation!=_generation: return
 if not AnglerIdentity.valid(result.get("identity",{})):
  _error("ยืนยัน Google แล้ว แต่เปิดโปรไฟล์เกมไม่ได้ · ลองเชื่อมต่อใหม่"); return
 needs_name=_automatic_name(result.identity)
 if not _switch_profile(user_id,result.identity):
  _error("เปิดเซฟของบัญชีนี้ไม่ได้ · ยังไม่เขียนทับข้อมูลเดิม"); return
 busy=false
 restoring=false
 account_ready=true
 status="ตั้งชื่อที่ต้องการใช้ในเกม" if needs_name else "เข้าสู่ระบบแล้ว"
 if not needs_name: authenticated.emit()
 changed.emit()

func save_player_name(value: String) -> void:
 if busy or not account_ready or not needs_name: return
 var chosen := value.strip_edges()
 var profile: AnglerProfile=get_node("/root/AnglerSave")
 if not AnglerIdentity.valid_name(chosen) or chosen=="นักตกปลา "+str(profile.data.identity.id).left(6):
  status="ใช้ชื่อ 2–24 ตัวอักษร ไม่ใช้บรรทัดใหม่หรือ < > [ ]"
  changed.emit()
  return
 busy=true
 status="กำลังบันทึกชื่อ…"
 changed.emit()
 var generation := _generation
 if not await ensure_session():
  if generation==_generation: _error("เชื่อมบัญชีไม่ได้ · ลองบันทึกชื่ออีกครั้ง")
  return
 if generation!=_generation: return
 var identity: Dictionary=profile.data.identity
 var result := await _http("/rest/v1/rpc/lakebound_rankings",{"payload":{"player_id":identity.id,"token":identity.token,"player_name":chosen,"catches":[]}},true)
 if generation!=_generation: return
 if result.get("ok")!=true:
  _error("บันทึกชื่อไม่ได้ · ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง")
  return
 # Reload the server identity before unlocking play; never trust only a local rename.
 await _load_account(generation)

func _switch_profile(account: String, identity: Dictionary) -> bool:
 if account!="offline" and (account.length()!=36 or account.contains("/") or account.contains("\\")): return false
 var folder := "user://"+PlayerSavePaths.ACCOUNTS+"/"+account
 if DirAccess.make_dir_recursive_absolute(folder)!=OK: return false
 var profile: AnglerProfile=get_node("/root/AnglerSave")
 var loaded := ProfileStore.load_profile(folder+"/profile.cfg")
 if loaded.incompatible: return false
 var data: Dictionary=loaded.data
 if not identity.is_empty():
  if data.identity.id!=identity.id and FileAccess.file_exists(folder+"/profile.cfg"): return false
  data.identity=identity.duplicate(true)
 if ProfileStore.save_profile(folder+"/profile.cfg",data)!=OK: return false
 profile.save_path=folder+"/profile.cfg"
 profile.data=data
 profile.incompatible=false
 profile.save_error=""
 var collection: Node=get_node("/root/FishCollection")
 collection.save_path=folder+"/collection.cfg"
 collection.load_records()
 var cloud:Node=get_node_or_null("/root/CloudSync")
 if cloud!=null:cloud.bind_profile(profile,account)
 var ranking: Node=get_node_or_null("/root/RankingOnline")
 if ranking!=null:
  ranking.enabled=account!="offline" and OS.get_environment("LAKEBOUND_BACKGROUND_SYNC")!="0"
  ranking.bind_profile(profile)
 var competition: Node=get_node_or_null("/root/Competition")
 if competition!=null:
  var saved := ConfigFile.new()
  var resume_room := ""
  if account!="offline" and saved.load(PlayerSavePaths.MATCH_SESSION)==OK and str(saved.get_value("session","identity",""))==str(data.identity.id) and str(saved.get_value("session","backend","supabase"))==("cloudflare" if competition.using_edge() else "supabase"):
   resume_room=str(saved.get_value("session","room",""))
  competition.forget_room()
  competition._identity=str(data.identity.id)
  competition._pending_room=resume_room
  competition._save_session()
 profile.changed.emit()
 collection.changed.emit()
 return true

func tutorial_path() -> String:
 return "user://"+PlayerSavePaths.ACCOUNTS+"/"+(user_id if signed_in() else "offline")+"/tutorial.cfg"

func cancel_login() -> void:
 _generation+=1
 waiting=false
 busy=false
 restoring=false
 _verifier=""
 _clear_pending()
 _close_listener()
 status="ยกเลิกการเข้าสู่ระบบแล้ว"
 changed.emit()

func choose_offline() -> bool:
 cancel_login()
 access_token=""; user_id=""; email=""; expires_at=0; account_ready=false; needs_name=false
 if not _switch_profile("offline",{}):
  _error("เปิดเซฟออฟไลน์ไม่ได้ · กรุณาลองอีกครั้ง")
  return false
 _offline_chosen=true
 changed.emit()
 return true

func sign_out() -> void:
 if busy: return
 _generation+=1
 # Local logout always succeeds, even without network. Server expiry still
 # applies to existing access JWTs; no claim of immediate remote revocation.
 access_token=""; refresh_token=""; user_id=""; email=""; expires_at=0
 account_ready=false
 needs_name=false
 _save_session()
 _switch_profile("offline",{})
 status="ออกจากระบบแล้ว"
 _offline_chosen=false
 changed.emit()

func _http(path: String, body: Dictionary, authenticated_request := false) -> Dictionary:
 while _http_busy: await get_tree().process_frame
 _http_busy=true
 var headers := PackedStringArray(["Content-Type: application/json","apikey: "+api_key])
 if authenticated_request: headers.append("Authorization: Bearer "+access_token)
 if request.request(base_url+path,headers,HTTPClient.METHOD_POST,JSON.stringify(body))!=OK:
  _http_busy=false; return {"error":"network_error"}
 var response: Array=await request.request_completed
 _http_busy=false
 if response[0]!=HTTPRequest.RESULT_SUCCESS or response[3].size()>65536: return {"error":"network_error"}
 var value: Variant=JSON.parse_string(response[3].get_string_from_utf8())
 if not value is Dictionary: return {"error":"invalid_response"}
 if response[1]!=200: return {"error":"request_rejected"}
 return value

func _save_session() -> void:
 var config := ConfigFile.new()
 config.set_value("session","refresh",refresh_token)
 config.save("user://google_session_v1.cfg")

func _close_listener() -> void:
 if _peer!=null: _peer.disconnect_from_host()
 _peer=null
 if _listener!=null: _listener.stop()
 _listener=null
 _android_bridge=null

func _error(message: String) -> void:
 waiting=false
 busy=false
 restoring=false
 _verifier=""
 _clear_pending()
 _close_listener()
 status=message
 changed.emit()

func _save_pending() -> void:
 if OS.get_name()!="Android": return
 var config := ConfigFile.new()
 config.set_value("oauth","verifier",_verifier)
 config.set_value("oauth","started",Time.get_unix_time_from_system())
 config.save("user://google_oauth_pending.cfg")

func _clear_pending() -> void:
 if OS.has_feature("web"): WebOAuth.clear()
 if OS.get_name()=="Android": ConfigFile.new().save("user://google_oauth_pending.cfg")

func _restore_pending() -> bool:
 var config := ConfigFile.new()
 if config.load("user://google_oauth_pending.cfg")!=OK: return false
 var value := str(config.get_value("oauth","verifier",""))
 var age := Time.get_unix_time_from_system()-float(config.get_value("oauth","started",0))
 if value.length()!=43 or age<0 or age>180: return false
 var wrapper: Object=Engine.get_singleton("JavaClassWrapper")
 _android_bridge=wrapper.wrap("com.godot.game.LakeboundAuthBridge") if wrapper!=null else null
 if _android_bridge==null or wrapper.get_exception()!=null: return false
 _verifier=value
 _redirect="com.zylaah.lakebound://auth/callback"
 _started_at=Time.get_ticks_msec()-int(age*1000)
 busy=true
 waiting=true
 status="กำลังรอผลจาก Google…"
 return true
