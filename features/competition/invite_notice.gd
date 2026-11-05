extends CanvasLayer
var friends: Node
var invitation: Dictionary={}
var _second: int=-1
var _previous_pause:=false
var _opened:=false
func _ready() -> void:
 friends=get_parent().get_node("Friends")
 friends.changed.connect(refresh)
 %Accept.pressed.connect(_accept)
 %Decline.pressed.connect(_decline)
 refresh()
func _process(_delta: float) -> void:
 var second:=int(Time.get_unix_time_from_system())
 if second!=_second:
  _second=second
  refresh()
func refresh() -> void:
 if friends==null or friends.service==null:return
 var now: float=friends.service.edge.social_now()
 invitation={}
 for item in friends.state().get("invites",[]):
  if float(item.get("expires_at",0))>now:
   invitation=item;break
 _set_open(not invitation.is_empty())
 if invitation.is_empty():
  return
 %Message.text=str(invitation.get("name","เพื่อน"))+" ชวนเข้าห้อง "+str(invitation.code)
 %Remaining.text="คำเชิญหมดอายุใน %d วินาที" % maxi(0,int(ceil(float(invitation.expires_at)-now)))
 %Error.text=friends.error_message
 %Error.visible=not friends.error_message.is_empty()
 var in_room: bool=not friends.service.room.is_empty() and friends.service.phase() in ["lobby","loading","countdown","running"]
 %Accept.disabled=friends.busy or friends.service.busy or not friends.online() or in_room
 %Accept.text="ออกจากห้องเดิมก่อนเข้าร่วม" if in_room else ("กำลังเข้าห้อง…" if friends.busy else "ยอมรับเข้าห้อง")
 %Decline.disabled=friends.busy
func _set_open(value: bool) -> void:
 %Alert.visible=value
 if value==_opened:return
 _opened=value
 if value:
  _previous_pause=get_tree().paused
  get_tree().paused=true
  %Decline.grab_focus()
 else:
  get_tree().paused=_previous_pause
func _exit_tree() -> void:
 if _opened:get_tree().paused=_previous_pause
func _accept() -> void:
 if invitation.is_empty():return
 await friends.act("accept_invite",{"invite_id":str(invitation.id)})
 refresh()
func _decline() -> void:
 if invitation.is_empty():return
 var ticket:=str(invitation.id)
 await friends.act("decline_invite",{"invite_id":ticket})
 refresh()
