extends Control
const ROW=preload("res://features/competition/friend_row.tscn")
var friends: Node
var _remove_id:=""
var _clock:=0.0
var _next_expiry:=0.0
const STATUS={"offline":"ออฟไลน์","online":"ออนไลน์","in_room":"ออนไลน์ · อยู่ในห้อง","playing":"ออนไลน์ · กำลังแข่งขัน"}
func _ready() -> void:
 friends=get_node("/root/Competition/Friends")
 %Close.pressed.connect(hide)
 %Add.pressed.connect(func():friends.act("request",{"code":%FriendCode.text.strip_edges().to_upper()}))
 %FriendCode.text_submitted.connect(func(_text: String):%Add.pressed.emit())
 %Copy.pressed.connect(func():DisplayServer.clipboard_set(str(friends.state().get("self",{}).get("code",""))))
 %RemoveConfirm.confirmed.connect(func():friends.act("remove",{"friend_id":_remove_id}))
 friends.changed.connect(render)
 render()
func open() -> void:
 show();friends.act("state");render()
func _process(delta: float) -> void:
 if not visible:return
 _clock+=delta
 if _clock>=1:
  _clock=0
  if _next_expiry>0 and friends.service.edge.social_now()>=_next_expiry:render()
func row(parent: Node,name_text: String,status: String,primary: String,action: Callable,secondary: String="",second: Callable=Callable()) -> Node:
 var item:=ROW.instantiate();parent.add_child(item)
 item.get_node("Description/Name").text=name_text;item.get_node("Description/Status").text=status
 item.get_node("Primary").text=primary;item.get_node("Primary").pressed.connect(action)
 item.get_node("Primary").disabled=friends.busy or not friends.online()
 item.get_node("Secondary").visible=not secondary.is_empty();item.get_node("Secondary").text=secondary
 if second.is_valid():item.get_node("Secondary").pressed.connect(second)
 item.get_node("Secondary").disabled=friends.busy
 return item
func render() -> void:
 if friends==null:return
 var state: Dictionary=friends.state()
 %OwnCode.text="รหัสเพื่อนของคุณ  "+str(state.get("self",{}).get("code","กำลังเชื่อมต่อ…"))
 %Copy.disabled=state.get("self",{}).get("code","")==""
 %Add.disabled=friends.busy or not friends.online()
 %Status.text=friends.error_message if not friends.error_message.is_empty() else (friends._notice if not friends._notice.is_empty() else ("เป็นเพื่อนกันแล้วจึงเห็นสถานะและส่งคำเชิญได้" if friends.online() else "เข้าสู่ระบบ Google เพื่อเชื่อมต่อรายชื่อเพื่อน"))
 for list in [%Friends,%Requests,%Outgoing,%Invites]:
  for child in list.get_children():list.remove_child(child);child.queue_free()
 var service: Node=friends.service
 for entry in state.get("friends",[]):
  var pid: String=entry.id
  var item:=row(%Friends,str(entry.name),STATUS.get(str(entry.get("status","offline")),"ออฟไลน์"),"ชวนเข้าห้อง",func():friends.act("invite",{"friend_id":pid}),"ลบ",func():_remove_id=pid;%RemoveConfirm.popup_centered())
  item.get_node("Primary").disabled=friends.busy or entry.get("status")!="online" or service.phase()!="lobby"
 for entry in state.get("incoming",[]):
  var pid: String=entry.id
  row(%Requests,str(entry.name),"ต้องการเป็นเพื่อนกับคุณ","ยอมรับ",func():friends.act("accept",{"friend_id":pid}),"ปฏิเสธ",func():friends.act("decline",{"friend_id":pid}))
 for entry in state.get("outgoing",[]):
  var pid: String=entry.id
  row(%Outgoing,str(entry.name),"รอการตอบรับ","ยกเลิกคำขอ",func():friends.act("cancel",{"friend_id":pid}))
 var server_now: float=service.edge.social_now()
 _next_expiry=0
 for invite in state.get("invites",[]):
  if float(invite.expires_at)<=server_now:continue
  if _next_expiry==0 or float(invite.expires_at)<_next_expiry:_next_expiry=float(invite.expires_at)
  var ticket: String=invite.id
  var item:=row(%Invites,str(invite.name),"ชวนเข้าห้อง "+str(invite.code),"เข้าห้อง",func():friends.act("accept_invite",{"invite_id":ticket}),"ปฏิเสธ",func():friends.act("decline_invite",{"invite_id":ticket}))
  item.get_node("Primary").disabled=friends.busy or service.busy or not friends.online() or (not service.room.is_empty() and service.phase() in ["lobby","loading","countdown","running"])
