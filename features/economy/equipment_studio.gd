extends Control
signal buy_requested(id:String)
signal equip_requested(id:String)
@export var details_width_ratio:=.32
@export var minimum_details_width:=320.0
@export var maximum_details_width:=440.0
var profile:AnglerProfile
var selected_item:TackleItem
@onready var preview:EquipmentModelPreview=%Preview
func _ready()->void:
 %Close.pressed.connect(close)
 %Focus.pressed.connect(_toggle_focus)
 %Reset.pressed.connect(func():preview.reset_view())
 %Info.pressed.connect(func():show_details(not %Information.visible))
 %HideDetails.pressed.connect(func():show_details(false))
 %Buy.pressed.connect(func():
  if selected_item!=null:buy_requested.emit(str(selected_item.id)))
 %Equip.pressed.connect(func():
  if selected_item!=null:equip_requested.emit(str(selected_item.id)))
 resized.connect(_layout_details)
func open_item(item:Resource)->void:
 selected_item=item
 %Feedback.text=""
 %Name.text=item.display_name
 %Focus.visible=item.kind=="rod"
 %Focus.text="ดูด้ามและไกด์"
 preview.show_full_rod=true
 %Information.hide()
 show();_layout_details();preview.set_item(item);refresh()
func show_details(value:=true)->void:
 %Information.visible=value
 _layout_details()
func _layout_details()->void:
 if not is_node_ready():return
 var width:=clampf(size.x*details_width_ratio,minimum_details_width,maximum_details_width) if %Information.visible else 0.0
 width=minf(width,size.x*.48)
 %Information.offset_left=-width
 preview.offset_right=-width
 %Floating.offset_right=-width
 %Info.text="ซ่อนรายละเอียด" if %Information.visible else "รายละเอียด / ซื้อ"
 %Info.visible=not %Information.visible
func refresh()->void:
 if selected_item==null:return
 var item:=selected_item
 %Details.text=preload("res://features/economy/tackle_row.gd").specifications(item)
 if not item.description.is_empty():%Details.text+="\n\n"+item.description
 %Actions.visible=profile!=null
 if profile==null:return
 var count:int=profile.spare_line_count(str(item.id)) if item.kind=="line" else profile.quantity(str(item.id))
 %Stock.text=("สำรอง %d ม้วน"%count if item.kind=="line" else "มี %d ชิ้น"%count)+" · %d เหรียญ"%profile.data.coins
 var error:=profile.equipment_fit_error(item)
 if item.kind=="box" and profile.box_weight()>item.capacity:
  error="ปลาที่เก็บ %.1f กก. เกินความจุกล่อง %.0f กก."%[profile.box_weight(),item.capacity]
 var selected:bool=str(profile.data.equipped.get("bait" if item.kind=="lure" else item.kind,""))==str(item.id)
 var pending:bool=not profile.data.pending.is_empty()
 %Buy.text="ซื้อ · %d เหรียญ%s"%[item.price," / %d ชิ้น"%item.quantity if item.quantity>1 else ""]
 %Buy.disabled=pending or profile.data.coins<item.price or (item.kind not in ["bait","lure","line"] and count>0)
 %Equip.text="ใช้อยู่" if selected and item.kind!="line" else "ใส่สาย" if item.kind=="line" else "เลือกใช้"
 %Equip.disabled=pending or count<=0 or not error.is_empty() or (selected and item.kind!="line")
 if selected and item.kind == "line":
  %Equip.text = "เปลี่ยนเป็นม้วนใหม่" if int(profile.data.spares.get(str(item.id),0)) > 0 else "ใช้อยู่"
  %Equip.disabled = pending or not error.is_empty() or int(profile.data.spares.get(str(item.id),0)) <= 0
 if item.kind in ["bait","lure"]:
  var result:=profile.candidate_rig_result(item)
  %Status.text=RigCompatibility.summary(result)
  %Status.modulate=Color(1,.82,.45) if result.allowed and not result.notes.is_empty() else Color(.65,.92,.79) if result.allowed else Color(1,.65,.5)
 else:
  %Status.text=error if not error.is_empty() else "เก็บปลาอยู่ %.1f / รับได้ %.0f กก."%[profile.box_weight(),item.capacity] if item.kind=="box" else "เลือกคันหรือรอกแล้ว ตรวจชุดที่ใช้ก่อนตกปลา" if item.kind in ["rod","reel"] else ""
  %Status.modulate=Color(1,.65,.5) if not error.is_empty() else Color(.72,.83,.78)
func show_feedback(ok:bool,message:String)->void:
 %Feedback.text=message
 %Feedback.modulate=Color(.65,.92,.79) if ok else Color(1,.65,.5)
func _toggle_focus()->void:
 preview.show_full_rod=not preview.show_full_rod
 %Focus.text="ดูด้ามและไกด์" if preview.show_full_rod else "ดูทั้งคัน"
 preview.reset_view()
func close()->void:
 hide();preview.release_model()
func _input(event:InputEvent)->void:
 if visible and event.is_action_pressed("ui_cancel"):
  if %Information.visible:show_details(false)
  else:close()
  get_viewport().set_input_as_handled()
