extends Control

@export var arrival_radius := 1.5
@export var save_path := PlayerSavePaths.TUTORIAL
var fishing: FishingController
var hud: FishingHUD
var destination := Vector3.ZERO
var arrived := false
var completed := false
var active := false
var success_time := 0.0

func bind(controller: FishingController, fishing_hud: FishingHUD) -> void:
 fishing = controller
 hud = fishing_hud
 var config := ConfigFile.new()
 completed = config.load(save_path) == OK and bool(config.get_value("tutorial", "completed", false))
 active = not completed and get_node("/root/FishCollection").records.is_empty()
 visible = active
 destination = fishing.player.global_position
 var definition := fishing.ecosystem.definition
 if definition is RiverDefinition:
  var side := signf(destination.x - definition.center_at(destination.z))
  destination.x = definition.center_at(destination.z) + side * (definition.half_width_at(destination.z) + 0.5)
  destination.y = definition.ground_height(Vector2(destination.x, destination.z)) + 0.1
 if not fishing.fish_landed.is_connected(_on_landed):
  fishing.fish_landed.connect(_on_landed)
 _process(0.0)

func _process(delta: float) -> void:
 if not active or not is_instance_valid(fishing):
  return
 visible = not hud.is_collection_open()
 $Card/Content/Skip.visible = not completed
 $Waypoint.hide()
 if completed:
  visible = fishing.state != FishingController.State.RESULT
  success_time = success_time + delta if visible else 0.0
  _show_step("สำเร็จ! จับปลาตัวแรกได้แล้ว", "ลองเปลี่ยนเหยื่อและความลึก เพื่อค้นหาปลาชนิดใหม่", 5)
  if success_time > 9.0:
   active = false
   hide()
  return
 var distance := Vector2(destination.x - fishing.player.global_position.x, destination.z - fishing.player.global_position.z).length()
 arrived = arrived or distance <= arrival_radius
 match fishing.state:
  FishingController.State.READY:
   if not arrived:
    _show_step("1/5 เดินไปริมน้ำ", "ลากจอยซ้าย / WASD ไปยังหมุด (%.0f ม.)\nลากพื้นที่ว่างเพื่อหมุนกล้อง" % distance, 0)
    _waypoint(destination, "▼ จุดตกปลา • %.0f ม." % distance)
   elif not fishing.ecosystem.definition.is_castable(fishing.get_aim_position()):
    _show_step("2/5 หันหน้าเข้าหาน้ำ", "ลากพื้นที่ว่างหมุนกล้องเข้าหาแม่น้ำ จนจุดเล็งอยู่ในน้ำ\nใช้เหยื่อและความลึกเริ่มต้นได้เลย", 1)
   else:
    _show_step("2/5 เหวี่ยงเบ็ด", "ลากจอยขวาเพื่อเล็งระยะ แล้วปล่อยนิ้วเพื่อเหวี่ยง\nปุ่มเหยื่อและความลึกอยู่ข้างจอยขวา ใช้ค่าเริ่มต้นได้เลย", 1)
  FishingController.State.CASTING:
   arrived = true
   _show_step("2/5 กำลังเหวี่ยงเบ็ด", "รอเหยื่อลงน้ำ แล้วสังเกตทุ่น", 1)
  FishingController.State.WAITING:
   if fishing.using_lure():
    _show_step("3/5 ล่อปลาด้วยเหยื่อปลอม", "ปุ่มแอ็กชัน / E: แตะ, แตะสองครั้ง, ค้าง, ปล่อย\nเมื่อปลากิน ให้ลากรอกขวาลงทันที / กด I", 2)
   else:
    _show_step("3/5 รอปลากินเหยื่อ", "ยังไม่ต้องหมุนรอก รอข้อความ ปลากินเบ็ด!\nเมื่อปลากิน ให้ลากรอกขวาลงทันที / กด I", 2)
  FishingController.State.BITE:
   _show_step("3/5 ปลากินแล้ว! วัดเบ็ดเลย", "ลากรอกขวาลงทันที / กด I เพื่อเกี่ยวปลาไว้", 2)
  FishingController.State.FIGHT:
   if fishing.tension >= fishing.red_start:
    _show_step("4/5 แรงตึงสูง! ผ่อนสาย", "ลากรอกขวาขึ้น / K จนพ้นสีแดง เพื่อป้องกันสายขาด", 3)
   elif fishing.tension < fishing.yellow_start:
    _show_step("4/5 เก็บสายเข้าหาตัว", "ลากรอกขวาลง / I ให้แรงตึงกลับเข้าสีเหลือง\nอย่าปล่อยสายหย่อนนาน ปลาจะหลุด", 3)
   else:
    _show_step("4/5 ประคองสีเหลือง แล้วดึงปลาเข้าฝั่ง", "ลง / I = เก็บสาย • ขึ้น / K = ผ่อนสาย • ซ้ายขวา / J L = คุมคัน\nค่อย ๆ เก็บสายจนปลาเข้าฝั่งและหมดแรง", 3)
  FishingController.State.LOST:
   _show_step("ลองอีกครั้งได้เลย", fishing.feedback + "\nรอสักครู่ แล้วเหวี่ยงใหม่ บทสอนจะช่วยต่อ", 1)
  FishingController.State.RESULT:
   hide()

func _show_step(title: String, instruction: String, progress: int) -> void:
 $Card/Content/Title.text = title
 $Card/Content/Instruction.text = instruction
 $Card/Content/Progress.value = progress

func _waypoint(point: Vector3, caption: String) -> void:
 var camera := get_viewport().get_camera_3d()
 if camera == null:
  return
 var screen := get_viewport_rect().size
 var projected := camera.unproject_position(point + Vector3.UP)
 if camera.is_position_behind(point):
  projected = screen * 0.5 + Vector2(signf(projected.x - screen.x * 0.5) * screen.x, 0)
 $Waypoint.position = Vector2(clampf(projected.x - 100, 12, screen.x - 212), clampf(projected.y, 230, screen.y - 240))
 $Waypoint.text = caption
 $Waypoint.show()

func _on_landed(_fish: RefCounted) -> void:
 if not active or completed:
  return
 completed = true
 var config := ConfigFile.new()
 config.set_value("tutorial", "completed", true)
 if config.save(save_path) != OK:
  push_warning("Could not save tutorial completion.")

func _skip() -> void:
 var config := ConfigFile.new()
 config.set_value("tutorial", "completed", true)
 if config.save(save_path) != OK:
  $Card/Content/Instruction.text = "บันทึกไม่สำเร็จ ลองข้ามบทสอนอีกครั้งได้"
  return
 completed = true
 active = false
 hide()
