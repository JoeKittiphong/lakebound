extends HBoxContainer

signal buy_requested(id: String)
signal equip_requested(id: String)
var item_id := ""

func _ready() -> void:
 $Buy.pressed.connect(func(): buy_requested.emit(item_id))
 $Equip.pressed.connect(func(): equip_requested.emit(item_id))

func bind(item: Resource, profile: AnglerProfile) -> void:
 item_id = String(item.id)
 $Name.text = item.display_name
 var count := int(profile.data.spares.get(String(item.id), 0)) if item.kind == "line" else profile.quantity(String(item.id))
 $Count.text = "มี %d" % count
 $Buy.text = "%d เหรียญ" % item.price
 $Buy.disabled = profile.data.coins < item.price or (item.kind not in ["bait", "lure", "line"] and count > 0)
 $Equip.disabled = count <= 0 or not profile.data.pending.is_empty()
 var selected := str(profile.data.equipped.get(item.kind, "")) == String(item.id)
 if item.kind == "lure":
  selected = str(profile.data.equipped.bait) == String(item.id)
 $Equip.text = "ใช้อยู่" if selected and item.kind != "line" else "ใส่ใหม่" if item.kind == "line" else "เลือกใช้"
 $Equip.disabled = $Equip.disabled or (selected and item.kind != "line")
