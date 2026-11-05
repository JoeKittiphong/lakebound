extends SceneTree
var failures := 0
var checks := 0
const SERVICE = preload("res://features/competition/match_service.gd")
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, label: String) -> void:
 checks+=1
 print("PASS: " if ok else "FAIL: ",label)
 if not ok: failures+=1
func fixture() -> Dictionary:
 var pid: String=root.get_node("AnglerSave").data.identity.id
 return {"schema":1,"id":"00000000-0000-4000-8000-000000000001","round_id":"00000000-0000-4000-8000-000000000002","code":"01234","host":pid,"map":"lotus_marsh","phase":"lobby","seed":1234,"pose_interval":2.0,"poll_interval":5.0,"duration":600,"rule":"total_weight","target_species":"","server_time":1000.0,"starts_at":0.0,"ends_at":0.0,
 "members":[{"id":pid,"name":"นักตกปลา QA","ready":false,"loaded":false,"departed":false,"online":true,"grams":0,"best":[],"rank":1},
 {"id":"a".repeat(32),"name":"เพื่อน","ready":true,"loaded":false,"departed":false,"online":true,"grams":0,"best":[],"rank":1}]}
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false
 root.get_node("RankingOnline").enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.data.identity.name="นักตกปลา QA"
 service._identity=profile.data.identity.id
 var snap := fixture()
 expect(SERVICE.valid_snapshot(snap),"bounded room snapshot accepted")
 expect(SERVICE.valid_snapshot(JSON.parse_string(JSON.stringify(snap))),"real JSON-decoded room snapshot accepted")
 expect(SERVICE.valid_room_code("00001"),"five digit room code preserves leading zeros")
 for code in ["1234","123456","12A45","１２３４５","1 234"]:
  expect(not SERVICE.valid_room_code(code),"invalid join code rejected: "+code)
 var invalid := snap.duplicate(true)
 invalid.members.append(invalid.members[0])
 expect(not SERVICE.valid_snapshot(invalid),"duplicate player rejected")
 invalid=snap.duplicate(true);invalid.starts_at="yesterday"
 expect(not SERVICE.valid_snapshot(invalid),"malformed timer rejected")
 var pose := {"id":"a".repeat(32),"p":[1,2,3],"yaw":1,"speed":3,"state":3,"seq":1}
 expect(MatchRealtime.valid_pose(pose),"valid pose accepted")
 var join_frame := MatchRealtime.protocol_message("realtime:match:qa","phx_join",{},1,"")
 var push_frame := MatchRealtime.protocol_message("realtime:match:qa","broadcast",{},2,"1")
 expect(join_frame.join_ref=="1" and push_frame.join_ref==join_frame.join_ref,"Phoenix join and broadcast use the same join reference")
 expect(MatchRealtime.protocol_message("phoenix","heartbeat",{},3,"1").join_ref==null,"heartbeat does not inherit channel join reference")
 pose.p=[1,INF,3]
 expect(not MatchRealtime.valid_pose(pose),"nonfinite position rejected")
 pose.p=[1,2,3];pose.state=99
 expect(not MatchRealtime.valid_pose(pose),"unknown pose state rejected")
 service.room=snap
 service._clock_server=1000
 service._clock_ticks=Time.get_ticks_msec()
 service.connected=true
 expect(service.phase()=="lobby" and not service.can_score(),"no scoring in lobby")
 snap.phase="countdown";snap.starts_at=1001;snap.ends_at=1601
 expect(service.phase()=="countdown","countdown uses synchronized clock")
 service._clock_server=1002
 expect(service.phase()=="running" and service.can_score(),"start progresses without receiving a realtime event")
 service._clock_server=1602
 expect(service.phase()=="finishing" and not service.can_score(),"local gate closes at deadline even while disconnected")
 service.room=fixture()
 var panel: Control=load("res://features/competition/match_panel.tscn").instantiate()
 panel.auto_travel=false
 root.add_child(panel)
 panel.open()
 expect(panel.get_node("%Rows").get_child_count()==2,"authored lobby binds two members")
 expect(panel.get_node("%Start").disabled,"host cannot start before all ready")
 service.room.members[0].ready=true
 panel.render()
 expect(not panel.get_node("%Start").disabled,"host start enabled when all ready")
 panel.close()
 expect(not panel.visible,"close hides panel without leaving room")
 panel.queue_free()
 service.room.clear()
 print("COMPETITION RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
