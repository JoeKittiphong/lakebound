extends SceneTree
var service: Node
var friends: Node
var role:=""
var invited:=false
var started:=false
var retry_at:=0
var panel: Control
var saw_notice:=false
var declined:=false
var reinvited:=false
var run_id:=""
var prefix:=""
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if OS.get_environment("LAKEBOUND_FRIENDS_QA")!="1":quit(1);return
 role=OS.get_environment("LAKEBOUND_FRIENDS_ROLE")
 run_id=OS.get_environment("LAKEBOUND_FRIENDS_RUN")
 prefix="res://exports/qa-two-player/"+run_id+"-"
 service=root.get_node("Competition");friends=service.get_node("Friends")
 root.get_node("RankingOnline").enabled=false
 var profile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.data.identity.id=(run_id+role).md5_text() if not run_id.is_empty() else ("1" if role=="host" else "2").repeat(32);profile.data.identity.name="เพื่อนทดสอบ"
 service.forget_room();service._identity=str(profile.data.identity.id)
 panel=load("res://features/competition/match_panel.tscn").instantiate();panel.auto_travel=false;root.add_child(panel);panel.hide()
 var auth=load("res://tests/fixtures/edge_auth_stub.gd").new();auth.access_token="qa."+service._identity+".signature";auth.expires_at=Time.get_unix_time_from_system()+3600;root.add_child(auth);service.account_auth=auth
 var until:=Time.get_ticks_msec()+45000
 while Time.get_ticks_msec()<until:
  await process_frame
  if not friends.online() or friends.busy:continue
  var social: Dictionary=friends.state()
  if not social.has("self"):continue
  if role=="host":
   var file:=FileAccess.open(prefix+"friend-host-code.txt",FileAccess.WRITE);file.store_string(str(social.self.code));file.close()
   if not social.get("incoming",[]).is_empty():friends.act("accept",{"friend_id":social.incoming[0].id})
   elif not social.get("friends",[]).is_empty():
    if service.room.is_empty() and not started:started=true;service.action("create",{"map":"river","duration":600})
    elif service.phase()=="lobby" and not invited:invited=true;friends.act("invite",{"friend_id":social.friends[0].id})
    elif service.phase()=="lobby" and invited and not reinvited and FileAccess.file_exists(prefix+"declined.txt"):
     reinvited=true;friends.act("invite",{"friend_id":social.friends[0].id})
  else:
   if social.get("friends",[]).is_empty() and social.get("outgoing",[]).is_empty() and Time.get_ticks_msec()>retry_at and FileAccess.file_exists(prefix+"friend-host-code.txt"):
    retry_at=Time.get_ticks_msec()+2000;friends.act("request",{"code":FileAccess.get_file_as_string(prefix+"friend-host-code.txt")})
   elif not social.get("invites",[]).is_empty() and service.room.is_empty():
    var notice=service.get_node("InviteNotice")
    if notice.get_node("%Alert").visible and not notice.get_node("%Accept").disabled:
     saw_notice=not panel.visible
     if not declined:
      await capture("alert")
      notice.get_node("%Decline").pressed.emit()
      while friends.busy:await process_frame
      await process_frame
      if notice.get_node("%Alert").visible or paused or not service.room.is_empty():finish(false);return
      declined=true
      print("PASS: decline button closes alert, restores input and leaves recipient outside room")
      var marker:=FileAccess.open(prefix+"declined.txt",FileAccess.WRITE);marker.store_string("declined");marker.close()
     else:notice.get_node("%Accept").pressed.emit()
  if not service.room.is_empty() and service.room.members.size()==2 and social.get("friends",[]).size()==1:
   if role=="guest":
    while friends.busy:await process_frame
    while service.busy:await process_frame
    await capture("accepted")
    var marker:=FileAccess.open(prefix+"accepted.txt",FileAccess.WRITE);marker.store_string("accepted");marker.close()
   else:
    var wait_until:=Time.get_ticks_msec()+15000
    while not FileAccess.file_exists(prefix+"accepted.txt") and Time.get_ticks_msec()<wait_until:await process_frame
   finish(role=="host" or (declined and saw_notice and panel.visible and not paused));return
 finish(false)
func capture(stage: String) -> void:
 if OS.get_environment("LAKEBOUND_FRIENDS_CAPTURE")!="1":return
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(prefix+stage+".png")
func finish(ok: bool) -> void:
 var result:={"ok":ok,"role":role,"declined_first_invite":declined,"notice_seen_while_lobby_closed":saw_notice,"lobby_open":panel.visible,"paused":paused,"room_code":service.room.get("code",""),"friends":friends.state().get("friends",[]).size(),"room_members":service.room.get("members",[]).size(),"social_error":friends.error_message,"room_error":service.error_message}
 var file:=FileAccess.open("res://exports/qa-two-player/friends-"+role+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result))
 print("FRIENDS GAME RESULT ",JSON.stringify(result));service.edge.close();quit(0 if ok else 1)
