extends PanelContainer
signal buy_requested(id: String)
signal equip_requested(id: String)
signal inspect_requested(item: Resource)
var item_id := ""
@export var bait_preview_height := 112.0

func _ready() -> void:
 $Content/Preview.inspect_requested.connect(func(item:Resource):inspect_requested.emit(item))
 $Content/Actions/Buy.pressed.connect(func(): buy_requested.emit(item_id))
 $Content/Actions/Equip.pressed.connect(func(): equip_requested.emit(item_id))

static func specifications(item: Resource) -> String:
 match item.kind:
  "rod":
   if item.rod_spec != null:
    var spec: RodSpec = item.rod_spec
    var rating := "ตีชุด %.1f–%.1f g" % [spec.cast_min_g, spec.cast_max_g]
    if "vertical_jig" in spec.techniques: rating = "จิ๊ก %.0f–%.0f g · PE ≤ %.1f" % [spec.jig_min_g, spec.jig_max_g, spec.pe_max]
    elif "boat_drop" in spec.techniques: rating = "หย่อน %.0f–%.0f g" % [spec.drop_min_g, spec.drop_max_g]
    elif spec.family == "pole": rating = "สายผูกปลาย %.1f–%.1f g" % [spec.pole_min_g, spec.pole_max_g]
    elif "fly_cast" in spec.techniques: rating = "ฟลาย #%d · โหมดยังไม่เปิด" % spec.fly_weight
    elif "ice_drop" in spec.techniques: rating = "ไอซ์ · โหมดยังไม่เปิด"
    return "%.2f ม. · %s · %s\n%s" % [spec.length_m, spec.power, spec.action, rating]
   return "รับแรง %.0f kgf" % item.strength
  "reel":
   var text := "จุสายสูงสุด %.0f ม. · เก็บ %.1f ม./วิ" % [item.length, item.reel_speed]
   if item.reel_spec != null and item.reel_spec.cast_min_g >= 0:
    text += "\n%sตี %.1f–%.0f g" % ["BFS · " if item.reel_spec.bfs else "", item.reel_spec.cast_min_g, item.reel_spec.cast_max_g]
   return text
  "line":
   if item.line_spec == null: return "ยังไม่มีสเปกสาย"
   var spec: LineSpec = item.line_spec
   var material_name:String={"mono":"ไนลอน","fluoro":"ฟลูออโรคาร์บอน","braid":"สายถัก PE","coated_mono":"ไนลอนเคลือบฟลูออโร","fly":"สายฟลาย"}.get(spec.material,"สายตกปลา")
   return "%s · %.2f mm\n%.1f kgf · %.0f ม." % [material_name, spec.diameter_mm, spec.break_kgf, item.length]
  "box": return "ความจุ %.0f กก." % item.capacity
  "lure": return {"float": "เหยื่อผิวน้ำ", "swim": "เหยื่อว่ายน้ำ", "sink": "เหยื่อจมน้ำ"}.get(item.motion, "เหยื่อปลอม") + " · %.1f g พร้อมตก\nใช้ซ้ำได้" % item.payload_g + attraction_text(item)
 return "ตัวเหยื่อ %.2f g + ชุดปลายสาย\nใช้ 1 ชิ้นต่อการเหวี่ยง" % item.payload_g + attraction_text(item)

func bind(item: Resource, profile: AnglerProfile) -> void:
 item_id = String(item.id)
 $Content/Icon.texture = item.shop_icon
 var use_model:bool=item.kind in ["rod","reel","bait","lure"] and item.model_scene!=null
 $Content/Icon.visible=not use_model
 $Content/Preview.visible=use_model
 $Content/Preview.custom_minimum_size.y = bait_preview_height if item.kind in ["bait", "lure"] else 184.0
 if use_model:$Content/Preview.set_item(item)
 $Content/Name.text = item.display_name
 $Content/Specs.text = (item.equipment_type + "\n" if not item.equipment_type.is_empty() else "") + specifications(item)
 tooltip_text = item.description
 var fit_error := profile.equipment_fit_error(item)
 var status: Label = $Content/Compatibility
 status.visible = item.kind != "box"
 status.text = "ใช้ไม่ได้ · " + fit_error if not fit_error.is_empty() else "เลือกเปลี่ยนได้"
 status.modulate = Color(1.0, 0.67, 0.55) if not fit_error.is_empty() else Color(0.62, 0.94, 0.79)
 if item.kind in ["bait", "lure"]:
  var result := profile.candidate_rig_result(item)
  status.text = RigCompatibility.summary(result)
  if result.allowed and not result.notes.is_empty(): status.modulate = Color(1.0, 0.85, 0.45)
 elif item.kind == "rod" and fit_error.is_empty():
  status.text = "เปลี่ยนคันแล้วตรวจชุดปลายสายอีกครั้ง"
 if item.kind == "rod":
  tooltip_text += "\n" + EquipmentFit.layout_label(item.mount_layout)
  if item.mount_layout != "fixed": tooltip_text += "\nเลือกคันแล้วใช้รอกที่เข้าคู่จากกระเป๋าโดยอัตโนมัติ"
 if not fit_error.is_empty(): tooltip_text += "\n" + fit_error
 var count := profile.spare_line_count(item_id) if item.kind == "line" else profile.quantity(item_id)
 $Content/Count.text = "สำรอง %d ม้วน" % count if item.kind == "line" else "ในกระเป๋า %d ชิ้น" % count
 $Content/Actions/Buy.text = "%d เหรียญ%s" % [item.price, " / %d ชิ้น" % item.quantity if item.quantity > 1 else ""]
 $Content/Actions/Buy.disabled = profile.data.coins < item.price or not profile.data.pending.is_empty() or (item.kind not in ["bait", "lure", "line"] and count > 0)
 var selected := str(profile.data.equipped.get("bait" if item.kind == "lure" else item.kind, "")) == item_id
 $Content/Actions/Equip.text = "ใช้อยู่" if selected and item.kind != "line" else "ใส่สาย" if item.kind == "line" else "เลือกใช้"
 if item.kind == "reel" and count > 0 and not fit_error.is_empty(): $Content/Actions/Equip.text = "คนละชนิด"
 $Content/Actions/Equip.disabled = count <= 0 or not profile.data.pending.is_empty() or (selected and item.kind != "line") or not fit_error.is_empty()
 $Content/Actions/Equip.tooltip_text = fit_error
 $Content/Count.modulate = Color(0.62, 0.94, 0.79) if selected else Color(0.7, 0.8, 0.76)

static func attraction_text(item:Resource)->String:
 if item.attraction==null:return ""
 return "\nวงดึงดูด %.1f ม.\n%s"%[item.attraction.radius_m,item.attraction.attraction_description]
