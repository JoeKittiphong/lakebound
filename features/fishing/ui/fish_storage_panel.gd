extends Control

signal opened
signal closed
const PAGE_SIZE := 8
@export var auto_frame_cooler := true
@export_range(1.0, 1.3) var framing_margin := 1.03
@export var opening_focus_bounds := AABB(Vector3(-2.9, 3.25, -1.6), Vector3(5.8, 0.79, 3.2))
var profile: AnglerProfile
var ecosystem: PondEcosystem
var map_id := "river"
var selected_index := -1
var selected_record: Dictionary = {}
var closing := false
var page := 0
var _finger := -1
var _press_at := Vector2.ZERO
var _moved := false
var _frame_points: Array[Vector3] = []
var _pending_action := ""
var _sale_snapshot: Array = []
@onready var preview: SubViewportContainer = $Card/Content/Body/Inventory/Preview
@onready var detail: VBoxContainer = $Card/Content/Body/Details/Content
@onready var viewport: SubViewport = $Card/Content/Body/Inventory/Preview/Viewport
@onready var animation: AnimationPlayer = $Card/Content/Body/Inventory/Preview/Viewport/Stage/Box/AnimationPlayer
@onready var box: Node3D = viewport.get_node("Stage/Box")
@onready var grid: Node3D = box.get_node("FishSlots")
@onready var camera: Camera3D = viewport.get_node("Stage/Camera")

func _ready() -> void:
 $Card/Content/Header/Close.pressed.connect(close)
 detail.get_node("Sell").pressed.connect(func(): _dispose(true))
 detail.get_node("SellAll").pressed.connect(_ask_sell_all)
 detail.get_node("Release").pressed.connect(func(): _dispose(false))
 detail.get_node("Confirm/Yes").pressed.connect(_confirm_action)
 detail.get_node("Confirm/No").pressed.connect(func(): _set_confirmation(false))
 animation.animation_finished.connect(_animation_finished)
 preview.gui_input.connect(_on_preview_input)
 detail.get_node("Pager/Navigation/Previous").pressed.connect(func(): _change_page(-1))
 detail.get_node("Pager/Navigation/Next").pressed.connect(func(): _change_page(1))
 # Fit the opening and fish, rather than shrinking everything to include the lid.
 for corner in 8:
  var point := opening_focus_bounds.position + opening_focus_bounds.size * Vector3(float(corner&1),float((corner>>1)&1),float((corner>>2)&1))
  _frame_points.append(point)
 preview.resized.connect(func(): _fit_camera.call_deferred())
 _fit_camera()

func _fit_camera() -> void:
 if not auto_frame_cooler or _frame_points.is_empty() or preview.size.y <= 0:
  return
 var minimum := Vector2(INF,INF)
 var maximum := Vector2(-INF,-INF)
 var inverse := camera.transform.affine_inverse()
 for point in _frame_points:
  var local := inverse * point
  minimum = minimum.min(Vector2(local.x,local.y))
  maximum = maximum.max(Vector2(local.x,local.y))
 var center := (minimum+maximum)*0.5
 camera.position += camera.basis.x*center.x + camera.basis.y*center.y
 var extent := (maximum-minimum)*framing_margin
 camera.size = maxf(extent.y,extent.x/(preview.size.x/preview.size.y))

func bind(value: AnglerProfile, pond: PondEcosystem) -> void:
 if is_instance_valid(profile) and profile.changed.is_connected(_refresh):
  profile.changed.disconnect(_refresh)
 profile = value
 ecosystem = pond
 profile.changed.connect(_refresh)

func _exit_tree() -> void:
 if is_instance_valid(profile) and profile.changed.is_connected(_refresh):
  profile.changed.disconnect(_refresh)

func open() -> void:
 if profile == null or visible:
  return
 closing = false
 page = 0
 _finger = -1
 selected_index = 0 if not profile.data.catches.is_empty() else -1
 selected_record = {}
 show()
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 _refresh()
 animation.play("open")
 opened.emit()

func close() -> void:
 if not visible or closing:
  return
 closing = true
 _finger = -1
 _set_confirmation(false)
 animation.play_backwards("open")

func _animation_finished(_name: StringName) -> void:
 if closing:
  hide()
  viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
  closing = false
  closed.emit()

func _refresh() -> void:
 if profile == null or not visible:
  return
 var catches: Array = profile.data.catches
 if not selected_record.is_empty():
  selected_index = catches.find(selected_record)
 if selected_index < 0 or selected_index >= catches.size():
  selected_index = 0 if not catches.is_empty() else -1
 $Card/Content/Header/Summary.text = "%.2f / %.0f กก." % [profile.box_weight(), profile.equipped("box").capacity if profile.equipped("box") != null else 0.0]
 _select(selected_index)

func _change_page(direction: int) -> void:
 if closing or animation.is_playing():
  return
 var last_page := maxi(0, ceili(profile.data.catches.size() / float(PAGE_SIZE)) - 1)
 page = clampi(page + direction, 0, last_page)
 selected_index = page * PAGE_SIZE if not profile.data.catches.is_empty() else -1
 selected_record = {}
 _refresh()

func _fill_slots() -> void:
 var catches: Array = profile.data.catches
 for cell in PAGE_SIZE:
  var index := page * PAGE_SIZE + cell
  var slot := grid.get_child(cell)
  if index < catches.size():
   slot.bind(catches[index], index, index == selected_index)
  else:
   slot.bind_empty()
 var last_page := maxi(0, ceili(catches.size() / float(PAGE_SIZE)) - 1)
 detail.get_node("Pager/Navigation/Previous").disabled = page <= 0
 detail.get_node("Pager/Navigation/Next").disabled = page >= last_page
 detail.get_node("Pager/Page").text = "หน้า %d / %d · %d ตัว" % [page + 1, last_page + 1, catches.size()]
 detail.get_node("Hint").text = "กล่องว่าง · เก็บปลาได้หลังจับสำเร็จ" if catches.is_empty() else "แตะโมเดลปลาในถังเพื่อเลือก · แสดงครั้งละ 8 ตัว"

func _select(index: int) -> void:
 selected_index = index
 page = floori(index / float(PAGE_SIZE)) if index >= 0 else 0
 _fill_slots()
 selected_record = profile.data.catches[index].duplicate(true) if index >= 0 and index < profile.data.catches.size() else {}
 _set_confirmation(false)
 var empty := selected_record.is_empty()
 detail.get_node("Name").text = "กล่องปลาว่าง" if empty else str(selected_record.name)
 detail.get_node("Info").text = "เก็บปลาหลังจับสำเร็จ\nแล้วกลับมาจัดการที่นี่" if empty else "น้ำหนัก %.2f กก.\nมูลค่า %d เหรียญ\n\nปล่อยคืนแหล่งน้ำเดิม\nประวัติการจับยังอยู่ในสมุด" % [selected_record.weight, maxi(1, int(round(float(selected_record.weight) * 35.0)))]
 detail.get_node("Sell").disabled = empty
 detail.get_node("SellAll").disabled = profile.data.catches.is_empty()
 detail.get_node("Release").disabled = empty
 for child in grid.get_children():
  child.set_pressed_no_signal(child.record_index == index)

func _dispose(sell: bool) -> void:
 if closing or selected_record.is_empty():
  return
 if not sell:
  _pending_action = "release"
  _set_confirmation(true)
  return
 var ok := profile.dispose_stored_catch(selected_index, selected_record, true)
 detail.get_node("Message").text = "ขายปลาแล้ว" if ok else _error()

func _ask_sell_all() -> void:
 if closing or profile == null or profile.data.catches.is_empty():
  return
 _pending_action = "sell_all"
 _sale_snapshot = profile.data.catches.duplicate(true)
 _set_confirmation(true)

func _confirm_action() -> void:
 if _pending_action == "release":
  _confirm_release()
 elif _pending_action == "sell_all" and not closing:
  if profile.data.catches != _sale_snapshot:
   _set_confirmation(false)
   detail.get_node("Message").text = "รายการปลาเปลี่ยนแล้ว กรุณาตรวจสอบอีกครั้ง"
   return
  var ok := profile.sell_catches()
  _set_confirmation(false)
  detail.get_node("Message").text = "ขายปลาหมดถังแล้ว" if ok else _error()

func _confirm_release() -> void:
 if closing or selected_record.is_empty():
  return
 # Keep a local immutable selection: profile.changed refreshes the UI on commit.
 var record := selected_record.duplicate(true)
 var same_map := str(record.map) == map_id
 var population: Array = ecosystem.snapshot() if same_map else profile.data.ponds.get(str(record.map), []).duplicate(true)
 var restored := _return_record(record, population)
 if restored.is_empty():
  detail.get_node("Message").text = "ไม่พบข้อมูลแหล่งน้ำเดิม — ยังเก็บปลาไว้ในกล่อง"
  _set_confirmation(false)
  return
 population.append(restored)
 var ok := profile.dispose_stored_catch(selected_index, record, false, population)
 if ok and same_map:
  # All entries came from the live ecosystem plus one validated species record.
  ecosystem.restore(population)
 detail.get_node("Message").text = "ปล่อยปลาคืนแหล่งน้ำเดิมแล้ว" if ok else _error()

func _return_record(record: Dictionary, population: Array) -> Dictionary:
 var species := FishCatalog.find(StringName(record.species))
 if species == null:
  return {}
 var snapshot: Dictionary = record.get("fish_snapshot", {}).duplicate(true)
 if snapshot.is_empty():
  # Legacy stored catches have no simulation snapshot. Restore their known
  # species/weight at an existing source-water position, with a fresh identity.
  if population.is_empty():
   return {}
  snapshot = {"species": str(record.species), "weight": float(record.weight), "position": population[0].position}
 var next_id := 1
 for fish in population:
  next_id = maxi(next_id, int(fish.id) + 1)
 var key: String = snapshot.get("persistent_key", (str(record.get("catch_id", "legacy")) + str(Time.get_ticks_usec())).sha256_text())
 for fish in population:
  if fish.get("persistent_key", "") == key:
   return {}
 snapshot.id = next_id
 snapshot.persistent_key = key
 snapshot.stamina = 1.0
 snapshot.hunger = 0.25
 snapshot.caution = 1.0
 return snapshot

func _error() -> String:
 return profile.save_error if not profile.save_error.is_empty() else "รายการเปลี่ยนแล้ว กรุณาเลือกปลาอีกครั้ง"

func _set_confirmation(value: bool) -> void:
 if not value:
  _pending_action = ""
  _sale_snapshot = []
 detail.get_node("Confirm/Label").text = "ขายปลาทุกตัวในถัง?" if _pending_action == "sell_all" else "ปล่อยตัวนี้? จะไม่ได้รับเหรียญ"
 detail.get_node("Confirm").visible = value
 detail.get_node("Sell").visible = not value
 detail.get_node("SellAll").visible = not value
 detail.get_node("Release").visible = not value

func _on_preview_input(event: InputEvent) -> void:
 if closing or animation.is_playing():
  return
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
  if event.pressed:
   _finger = -2
   _press_at = event.position
   _moved = false
  elif _finger == -2:
   _finger = -1
   if not _moved and event.position.distance_to(_press_at) < 12:
    _pick_inventory(event.position)
 elif event is InputEventMouseMotion and _finger == -2:
  _moved = _moved or event.position.distance_to(_press_at) >= 12
 elif event is InputEventScreenTouch:
  if event.pressed and _finger == -1:
   _finger = event.index
   _press_at = event.position
   _moved = false
  elif not event.pressed and event.index == _finger:
   _finger = -1
   if not event.canceled and not _moved and event.position.distance_to(_press_at) < 12:
    _pick_inventory(event.position)
 elif event is InputEventScreenDrag and event.index == _finger:
  _moved = _moved or event.position.distance_to(_press_at) >= 12
 preview.accept_event()

func _pick_inventory(point: Vector2) -> void:
 var pixel := point * Vector2(viewport.size) / preview.size
 var origin := camera.project_ray_origin(pixel)
 var direction := camera.project_ray_normal(pixel)
 var nearest := INF
 var chosen := -1
 for slot: StoredFishDisplay in grid.get_children():
  if slot.disabled:
   continue
  var inverse := slot.global_transform.affine_inverse()
  var hit: Variant = slot.pick_bounds().intersects_ray(inverse * origin, inverse.basis * direction)
  if hit != null:
   var distance := origin.distance_squared_to(slot.to_global(hit))
   if distance < nearest:
    nearest = distance
    chosen = slot.record_index
 if chosen >= 0:
  _select(chosen)

func _input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  close()
  get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  _finger = -1
