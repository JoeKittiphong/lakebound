extends "res://features/economy/equipment_studio.gd"
signal unequip_requested(slot: String)
var allow_unequip := false

func _ready()->void:
 %Unequip.pressed.connect(func():
  if selected_item != null: unequip_requested.emit("bait" if selected_item.kind == "lure" else selected_item.kind))
 %Buy.pressed.connect(func():
  if selected_item!=null:buy_requested.emit(str(selected_item.id)))
 %Equip.pressed.connect(func():
  if selected_item!=null:equip_requested.emit(str(selected_item.id)))
 %Reset.pressed.connect(func():preview.reset_view())
 %Focus.pressed.connect(_toggle_focus)

func open_item(item:Resource)->void:
 selected_item=item
 %Feedback.text=""
 %Name.text=item.display_name
 %Focus.visible=item.kind=="rod"
 %Focus.text="ดูด้ามและไกด์"
 preview.show_full_rod=true
 show();preview.set_item(item);refresh()

func refresh()->void:
 super.refresh()
 %Unequip.visible = false
 if selected_item != null and profile != null:
  var slot := "bait" if selected_item.kind == "lure" else selected_item.kind
  %Unequip.visible = allow_unequip and profile.equipped(slot) == selected_item
  %Unequip.disabled = not profile.data.pending.is_empty()
  %Unequip.text = "ถอดอุปกรณ์นี้" if slot != "rod" else "ถอดคันและชุดที่ติดอยู่"
 if selected_item!=null and profile!=null and selected_item.kind in ["rod","reel"]:
  %Equip.disabled=not profile.data.pending.is_empty() or profile.quantity(str(selected_item.id))<=0 or not profile.equipment_fit_error(selected_item).is_empty()
 if selected_item!=null and profile!=null and not %Equip.disabled and not (selected_item.kind == "line" and profile.equipped("line") == selected_item):
  %Equip.text="เลือกคันนี้ → รอก" if selected_item.kind=="rod" and selected_item.mount_layout!="fixed" else "เลือกคันนี้ → เอ็น" if selected_item.kind=="rod" else "เลือกรอกนี้ → เอ็น" if selected_item.kind=="reel" else "ใส่สาย → เหยื่อ" if selected_item.kind=="line" else "เลือกใช้"
 if selected_item==null or profile==null:return
 var reason:=EquipmentChoiceRules.error(profile,selected_item)
 if not reason.is_empty():%Status.text="ใช้ไม่ได้ · "+EquipmentChoiceRules.explanation(profile,selected_item)
 elif selected_item.kind in ["rod","reel","line"]:%Status.text="✓ ใช้กับชุดนี้ได้"

func show_details(_value:=true)->void:pass
func _layout_details()->void:pass
func _input(_event:InputEvent)->void:pass
