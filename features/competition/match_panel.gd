extends Control
signal opened
signal closed
@export var auto_travel := true
var service: Node
var _travelling := false
var _last_phase := "none"
const ROW = preload("res://features/competition/match_row.tscn")
const ERRORS = {
 "google_login_required":"เข้าสู่ระบบด้วย Google ก่อนเข้าร่วมการแข่งขัน", "account_mismatch":"บัญชีไม่ตรงกับโปรไฟล์ · กลับเข้าสู่ระบบอีกครั้ง",
 "name_required":"ตั้งชื่อในหน้าโปรไฟล์ก่อนเข้าร่วม", "room_not_found":"ไม่พบห้อง · ตรวจรหัสอีกครั้ง",
 "room_full":"ห้องเต็มแล้ว (สูงสุด 5 คน)", "room_locked":"ห้องนี้เริ่มแข่งขันแล้ว",
 "room_codes_busy":"ยังสร้างรหัสห้องไม่ได้ · ลองใหม่อีกครั้ง",
 "no_open_rooms":"ยังไม่มีห้องที่ว่างและรอผู้เล่น · ลองอีกครั้งหรือสร้างห้อง",
 "capacity_full":"ผู้เล่นออนไลน์เต็มชั่วคราว · รอให้มีที่ว่างแล้วลองใหม่",
 "superseded_session":"บัญชีนี้เปิดเล่นในอีกหน้าต่างแล้ว · ออกจากระบบแล้วเข้าใหม่เพื่อกลับมาเล่น",
 "turn_daily_limit":"การเชื่อมต่อสำรองวันนี้ถึงขีดจำกัดแล้ว · ลองใหม่ภายหลัง",
 "monthly_capacity_reached":"โควตาแข่งขันช่วงนี้เต็มแล้ว · ยังเล่นออฟไลน์ได้",
 "rate_limited":"กดเร็วเกินไป · กำลังรอแล้วลองใหม่", "busy_retry":"ระบบกำลังรับผู้เล่น · กำลังลองใหม่",
 "invalid_duration":"เลือกระยะเวลา 3, 5, 10, 15 หรือ 20 นาที", "invalid_rule":"เลือกกติกาการแข่งขัน",
 "invalid_target_species":"เลือกชนิดปลาที่มีอยู่ในสนามนี้",
 "catch_limit":"จำนวนปลาถึงขีดจำกัดของรอบนี้แล้ว",
 "fish_busy":"ปลาตัวนี้มีผู้เล่นอื่นเกี่ยวอยู่ · รอปลาตัวอื่น", "fish_already_caught":"ปลาตัวนี้ถูกจับไปแล้ว",
 "fish_claim_expired":"สิทธิ์เกี่ยวปลาหมดอายุ · เหวี่ยงเบ็ดใหม่", "fish_claim_required":"ต้องยืนยันสิทธิ์ปลาก่อนส่งผล",
 "already_hooked":"ยังมีปลาติดเบ็ดอยู่", "fish_metadata_mismatch":"ข้อมูลปลาไม่ตรงกับสนาม · กลับเข้าห้องใหม่",
 "players_not_ready":"ต้องมี 2–5 คน พร้อมครบและยังเชื่อมต่ออยู่", "host_only":"เฉพาะเจ้าของห้องเท่านั้น",
 "already_in_match":"คุณมีห้องอยู่แล้ว · กดหาห้องด่วนเพื่อกลับเข้าห้องเดิม",
 "network_error":"การเชื่อมต่อขัดข้อง · กำลังลองใหม่", "outside_match":"ส่งผลไม่ทันเวลา · ไม่นับปลาตัวนี้",
 "anonymous_auth_unavailable":"ยังเชื่อมระบบห้องไม่ได้ · ผู้ดูแลต้องเปิด Anonymous Sign-ins ใน Supabase",
 "not_configured":"ยังไม่ได้ตั้งค่าการเชื่อมต่อ", "invalid_response":"ข้อมูลห้องไม่สมบูรณ์ · ลองเชื่อมต่อใหม่"
}

func _ready() -> void:
 service=get_node_or_null("/root/Competition")
 for entry in RegionCatalog.MAPS: %Map.add_item(entry.name)
 for seconds in MatchRules.DURATIONS: %Duration.add_item("เวลา %d นาที" % (seconds/60))
 %Duration.select(2)
 for label in MatchRules.NAMES: %Rule.add_item(label)
 %Rule.select(1)
 %Map.item_selected.connect(func(_index: int): _species_options())
 %Rule.item_selected.connect(func(_index: int): %Species.visible=%Rule.selected==0)
 _species_options()
 %Species.visible=false
 %Create.pressed.connect(_create_room)
 %QuickJoin.pressed.connect(func(): service.action("quick_join"))
 %Join.pressed.connect(_join_room)
 %Code.text_submitted.connect(func(_text: String): %Join.pressed.emit())
 %Ready.pressed.connect(func(): service.action("ready",{"ready":not service.member(service._identity).get("ready",false)}))
 %Start.pressed.connect(func(): service.action("start"))
 %Leave.pressed.connect(func(): service.action("leave"))
 %Resume.pressed.connect(_travel)
 %Close.pressed.connect(close)
 %FriendsOpen.pressed.connect(func():$FriendsPanel.open())
 if service!=null:service.get_node("Friends").joined_room.connect(func():$FriendsPanel.hide();open())
 if service!=null:service.get_node("Friends").changed.connect(_friends_changed)
 %Rematch.pressed.connect(func(): service.action("rematch"))
 if service!=null: service.changed.connect(render)
 _friend_badge()
 render()

func _friend_badge() -> void:
 var state: Dictionary=service.get_node("Friends").state()
 var count: int=state.get("incoming",[]).size()+state.get("invites",[]).size()
 %FriendsOpen.text="เพื่อน / คำเชิญ"+(" (%d)" % count if count>0 else "")
 %FriendsOpen.disabled=not service.using_edge()

func _friends_changed() -> void:
 _friend_badge()
 if visible:render()

func _species_options() -> void:
 %Species.clear()
 for id in MatchRules.species_for(str(RegionCatalog.MAPS[%Map.selected].id)):
  var fish: Resource=FishCatalog.find(StringName(id))
  if fish==null: continue
  %Species.add_item("ปลาที่กำหนด · "+str(fish.display_name))
  %Species.set_item_metadata(%Species.item_count-1,id)

func _create_room() -> void:
 var settings := {"map":RegionCatalog.MAPS[%Map.selected].id,"duration":MatchRules.DURATIONS[%Duration.selected],"rule":MatchRules.MODES[%Rule.selected]}
 if %Rule.selected==0: settings["target_species"]=%Species.get_item_metadata(%Species.selected)
 service.action("create",settings)

func _join_room() -> void:
 var code: String=%Code.text.strip_edges()
 if not service.valid_room_code(code):
  %Status.text="ใส่รหัสห้องเป็นตัวเลข 5 หลัก"
  return
 service.action("join",{"code":code})

func open() -> void:
 show()
 opened.emit()
 if service!=null and not service.room.is_empty(): service.action("state")
 render()

func close() -> void:
 $FriendsPanel.hide()
 hide()
 closed.emit()

func close_top_layer() -> void:
 if $FriendsPanel.visible:$FriendsPanel.hide()
 else:close()

func render() -> void:
 if service==null: return
 var room: Dictionary=service.room
 var has_room := not room.is_empty()
 %Entry.visible=not has_room
 %Lobby.visible=has_room
 var error: String=service.error_message
 if error.is_empty() and service.using_edge() and service.edge.last_error=="superseded_session":error="superseded_session"
 %Status.text=ERRORS.get(error,"เชื่อมต่อไม่สำเร็จ · "+error) if not error.is_empty() else ("กำลังหาห้อง…" if service.busy and service._inflight_op=="quick_join" else ("กำลังเชื่อมต่อ…" if service.busy else "ห้องเปิด · 2–5 คน · เข้าได้โดยไม่ต้องเป็นเพื่อน"))
 %Create.disabled=service.busy
 %QuickJoin.disabled=service.busy
 %QuickJoin.text="กำลังหาห้อง…" if service.busy and service._inflight_op=="quick_join" else "หาห้องด่วน · ทุกคน"
 %Join.disabled=service.busy
 %Rules.text=MatchRules.description(room)+" · ชุดมาตรฐาน · ส่งผลก่อนหมดเวลา" if has_room else "เลือกเวลาและกติกาเมื่อสร้างห้อง · หาห้องด่วนจะใช้กติกาของห้องที่พบ"
 if not has_room: return
 %RoomTitle.text="รหัสห้อง  "+str(room.code)+"   ·   "+RegionCatalog.find(room.map).name
 var phase: String=service.phase()
 var previous_phase := _last_phase
 _last_phase=phase
 var lobby := phase=="lobby"
 var own: Dictionary=service.member(service._identity)
 var host: bool=room.host==service._identity
 %Ready.visible=lobby
 %Ready.text="ยกเลิกพร้อม" if own.get("ready",false) else "พร้อมแข่งขัน"
 %Ready.disabled=service.busy
 %Start.visible=lobby and host
 %Start.disabled=service.busy
 var count := 0
 var all_ready := true
 for item in room.members:
  if item.departed: continue
  count+=1
  all_ready=all_ready and item.ready and item.online
 %Start.disabled=%Start.disabled or count<2 or not all_ready
 %Leave.disabled=service.busy
 %Resume.visible=phase in ["loading","countdown","running","finishing"]
 %Rematch.visible=phase in ["finished","cancelled"] and host
 %Rematch.disabled=service.busy
 %Phase.text={"lobby":"รอผู้เล่น · %d/5 คน" % count,"loading":"กำลังเตรียมสนาม · รอทุกคนโหลดเสร็จ","countdown":"เตรียมตัว · กำลังนับถอยหลัง","running":"กำลังแข่งขัน","finishing":"หมดเวลา · กำลังยืนยันผล","finished":"จบการแข่งขัน · ผลยืนยันแล้ว","cancelled":"ยกเลิกรอบ · ผู้เล่นออกหรือโหลดสนามไม่ทัน"}.get(phase,phase)
 for child in %Rows.get_children():
  %Rows.remove_child(child)
  child.queue_free()
 var row_number := 0
 for item in room.members:
  if lobby and item.departed: continue
  row_number+=1
  var row := ROW.instantiate()
  %Rows.add_child(row)
  row.get_node("Line/Rank").text="%02d" % (row_number if lobby else int(item.rank))
  row.get_node("Line/Player").text=str(item.name)+( " · คุณ" if item.id==service._identity else "")+(" · เจ้าของห้อง" if item.id==room.host else "")
  var state := "ออกจากรอบ" if item.departed else ("พร้อม" if item.ready else "ยังไม่พร้อม")
  if not lobby and not item.departed: state="%.3f กก." % (float(item.grams)/1000.0)
  if not item.online and not item.departed: state+=" · ขาดการเชื่อมต่อ"
  row.get_node("Line/Score").text=state
  var friend_button: Button=row.get_node("Line/AddFriend")
  friend_button.visible=service.using_edge() and item.id!=service._identity and not item.departed
  if friend_button.visible:
   var friends: Node=service.get_node("Friends")
   var social: Dictionary=friends.state()
   var target: String=item.id
   var already: bool=social.get("friends",[]).any(func(f):return f.id==target)
   var sent: bool=social.get("outgoing",[]).any(func(f):return f.id==target)
   var incoming: bool=social.get("incoming",[]).any(func(f):return f.id==target)
   friend_button.text="เป็นเพื่อนแล้ว" if already else ("ส่งคำขอแล้ว" if sent else ("รับเป็นเพื่อน" if incoming else "เพิ่มเพื่อน"))
   friend_button.disabled=already or sent or friends.busy or not friends.online()
   var room_id: String=room.id
   friend_button.pressed.connect(func():
    if incoming:await friends.act("accept",{"friend_id":target})
    else:await friends.act("request_member",{"room_id":room_id,"friend_id":target}))
   if not friends.error_message.is_empty():%Status.text=friends.error_message
   elif not friends._notice.is_empty():%Status.text=friends._notice
 if auto_travel and phase in ["loading","countdown","running"]: _travel.call_deferred()
 elif not auto_travel and previous_phase=="lobby" and phase=="loading" and visible: close()

func _travel() -> void:
 if _travelling or service.room.is_empty(): return
 _travelling=true
 get_tree().paused=false
 get_tree().set_meta("pending_map_scene",str(RegionCatalog.find(service.room.map).scene))
 var error := get_tree().change_scene_to_file("res://features/loading/map_transition.tscn")
 if error!=OK:
  _travelling=false
  %Status.text="โหลดสนามไม่ได้ · กดกลับเข้าสนามเพื่อลองใหม่"
