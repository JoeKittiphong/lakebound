extends SceneTree
var service: Node
var panel: Control
var role:=""
var clicked:=false
var requested:=false
var expected_room:=""
var observed_strangers:=false
var published:=false
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if OS.get_environment("LAKEBOUND_PUBLIC_QA")!="1":quit(1);return
 role=OS.get_environment("LAKEBOUND_PUBLIC_ROLE")
 service=root.get_node("Competition");root.get_node("RankingOnline").enabled=false
 var profile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.data.identity.name="ผู้เล่นทั่วไป"
 service.forget_room();service._identity=str(profile.data.identity.id)
 var auth=load("res://tests/fixtures/edge_auth_stub.gd").new();auth.access_token="qa."+service._identity+".signature";auth.expires_at=Time.get_unix_time_from_system()+3600;root.add_child(auth);service.account_auth=auth
 panel=load("res://features/competition/match_panel.tscn").instantiate();panel.auto_travel=false;root.add_child(panel);panel.open()
 var until:=Time.get_ticks_msec()+45000
 while Time.get_ticks_msec()<until:
  var file_path:="res://exports/qa-two-player/public-room.json"
  if not clicked:
   if role=="host":clicked=true;panel.get_node("%QuickJoin").pressed.emit()
   elif FileAccess.file_exists(file_path):
    var parser:=JSON.new()
    if parser.parse(FileAccess.get_file_as_string(file_path))!=OK:
     await process_frame
     continue
    var expected: Variant=parser.data
    if expected is Dictionary and expected.get("run")==OS.get_environment("LAKEBOUND_PUBLIC_RUN"):
     expected_room=str(expected.room);clicked=true;panel.get_node("%QuickJoin").pressed.emit()
  if not service.room.is_empty():
   if role=="host":
    if not published:
     var file:=FileAccess.open(file_path,FileAccess.WRITE);file.store_string(JSON.stringify({"run":OS.get_environment("LAKEBOUND_PUBLIC_RUN"),"room":service.room.id}));file.close()
     published=true
   elif service.room.id!=expected_room:finish(false,"quick join picked a different room");return
   var friends: Node=service.get_node("Friends")
   if service.room.members.size()==2:
    var state: Dictionary=friends.state()
    if state.get("friends",[]).is_empty():observed_strangers=true
    var button: Button
    for row in panel.get_node("%Rows").get_children():
     var candidate: Button=row.get_node("Line/AddFriend")
     if candidate.visible:button=candidate
    if button!=null and not button.disabled and not requested:
     if role=="host" and button.text=="เพิ่มเพื่อน":requested=true;button.pressed.emit()
     elif role=="guest" and button.text=="รับเป็นเพื่อน":requested=true;button.pressed.emit()
    if state.get("friends",[]).size()==1 and button!=null and button.text=="เป็นเพื่อนแล้ว" and button.disabled:
     finish(observed_strangers and requested,"");return
  await process_frame
 finish(false,"timeout")
func finish(ok: bool,detail: String) -> void:
 var result:={"ok":ok,"role":role,"quick_pressed":clicked,"joined_as_strangers":observed_strangers,"friend_button_used":requested,"members":service.room.get("members",[]).size(),"error":service.error_message,"detail":detail}
 var file:=FileAccess.open("res://exports/qa-two-player/public-"+role+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result))
 print("PUBLIC MATCH RESULT ",JSON.stringify(result));service.edge.close();quit(0 if ok else 1)
