extends Node
signal changed
signal joined_room
var service: Node
var busy:=false
var error_message:=""
var _connecting:=false
var _retry_at:=0
var _notice:=""
const ERRORS={"not_a_friend":"ต้องเป็นเพื่อนกันก่อนจึงชวนได้","invalid_friend_code":"รหัสเพื่อนต้องมี 8 ตัว เช่น A1B2C3D4","friend_not_found":"ไม่พบรหัสเพื่อนนี้","invalid_friend":"เพิ่มตัวเองเป็นเพื่อนไม่ได้","friend_request_pending":"มีคำขอจากคนนี้อยู่แล้ว · กดยอมรับคำขอได้เลย","friend_request_missing":"ไม่พบคำขอแล้ว · ลองเปิดรายชื่อใหม่","friend_limit":"รายชื่อหรือคำขอเต็มแล้ว · จัดการรายการเดิมก่อน","friend_daily_limit":"ส่งคำขอครบจำนวนที่กำหนดในวันนี้แล้ว","invite_lobby_only":"สร้างหรือเข้าห้องที่รอผู้เล่นก่อนชวนเพื่อน","friend_offline":"เพื่อนออฟไลน์แล้ว","friend_busy":"เพื่อนอยู่ในห้องอื่นแล้ว","room_full":"ห้องเต็มแล้ว · สูงสุด 5 คน","invite_limit":"คำเชิญของเพื่อนเต็มแล้ว · ลองอีกครั้งภายหลัง","invite_expired":"คำเชิญหมดอายุ หรือห้องเริ่มแข่ง/ปิดไปแล้ว","already_in_match":"ออกจากห้องปัจจุบันก่อนรับคำเชิญ","network_error":"การเชื่อมต่อขัดข้อง · ลองอีกครั้ง","rate_limited":"กดเร็วเกินไป · รอสักครู่","superseded_session":"บัญชีนี้กำลังใช้งานในหน้าต่างอื่น"}
func setup(owner_service: Node) -> void:
 service=owner_service
 service.edge.social_changed.connect(func():changed.emit())
 service.edge.connection_changed.connect(func(_value: bool):changed.emit())
func _process(_delta: float) -> void:
 if service==null or not service.enabled or not service.edge.enabled:return
 if service.account_auth==null or not service.account_auth.signed_in():return
 if _connecting or service.busy or Time.get_ticks_msec()<_retry_at:return
 if not service.edge.connected or service._expires<Time.get_unix_time_from_system()+60:_connect()
func _connect() -> void:
 _connecting=true;_retry_at=Time.get_ticks_msec()+10000
 if await service._authenticate():await service.edge.ensure_session(service._access)
 _connecting=false;changed.emit()
func state() -> Dictionary:
 return service.edge.social if service!=null else {}
func online() -> bool:
 return service!=null and service.edge.connected
func act(op: String,data: Dictionary={}) -> void:
 if busy or service==null:return
 busy=true;error_message="";_notice="";changed.emit()
 if not await service._authenticate() or not await service.edge.ensure_session(service._access):
  error_message="เข้าสู่ระบบและเชื่อมต่อออนไลน์ก่อน";busy=false;changed.emit();return
 var payload:=data.duplicate(true);payload.op=op
 var result: Dictionary=await service.edge.call_server("social",payload)
 if result.has("error"):error_message="ต้องอยู่ในห้องเดียวกันจึงเพิ่มเพื่อนจากรายชื่อผู้เล่นได้" if result.error=="not_a_room_member" else ERRORS.get(str(result.error),"ทำรายการไม่สำเร็จ · "+str(result.error))
 elif op=="accept_invite" and result.get("room") is Dictionary:
  # Only replace local state after the server confirms membership in the invited room.
  if service.valid_snapshot(result.room):
   if not service.room.is_empty() and service.room.id!=result.room.id:service.forget_room(false)
   service._edge_snapshot(result.room)
   busy=false
   joined_room.emit()
 elif op in ["request","request_member"]:_notice="ส่งคำขอเป็นเพื่อนแล้ว"
 elif op=="invite":_notice="ส่งคำเชิญแล้ว · มีอายุ 60 วินาที"
 busy=false;changed.emit()
