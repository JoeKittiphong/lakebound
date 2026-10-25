extends Control
@export_file("*.tscn") var next_scene_path: String = "res://features/menu/main_menu_ui.tscn"
@export_range(0.0, 30.0) var minimum_display_seconds: float = 0.0
@export var require_start_input: bool = true
@export var wait_for_intro: bool = true
@onready var bar: ProgressBar = $SafeArea/LoadPanel/Content/SwimmingProgress/ProgressBar
@onready var status: Label = $SafeArea/LoadPanel/Content/StatusRow/Status
@onready var percent: Label = $SafeArea/LoadPanel/Content/StatusRow/Percent
@onready var start_button: Button = $SafeArea/LoadPanel/Content/StartButton
@onready var retry_button: Button = $SafeArea/LoadPanel/Content/RetryButton
@onready var cinematic: Node3D = $Cinematic
var elapsed := 0.0
var requested := false
var failed := false
var ready_to_start := false
var menu_ui: Control
var _next_scene: PackedScene
var _transitioning := false

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
  get_tree().quit()

func _ready() -> void:
 # Present the light lakeside scene before requesting the full game.
 await get_tree().process_frame
 await get_tree().process_frame
 _request_load()

func _request_load() -> void:
 var error := ResourceLoader.load_threaded_request(next_scene_path)
 requested = error == OK
 if not requested:
  _show_error()

func _process(delta: float) -> void:
 elapsed += delta
 if not requested or failed or _transitioning or ready_to_start:
  return
 var progress: Array = []
 var state := ResourceLoader.THREAD_LOAD_LOADED if _next_scene != null else ResourceLoader.load_threaded_get_status(next_scene_path, progress)
 if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
  _show_error()
  return
 var actual: float = 1.0 if _next_scene != null else (float(progress[0]) if not progress.is_empty() else 0.0)
 bar.value = move_toward(bar.value, actual * 100.0, delta * 65.0)
 percent.text = "%d%%" % int(bar.value)
 if state != ResourceLoader.THREAD_LOAD_LOADED:
  return
 if _next_scene == null:
  _next_scene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
  if _next_scene == null:
   _show_error()
   return
 if wait_for_intro and not cinematic.finished:
  status.text = "พร้อมแล้ว · พักชมบรรยากาศสักครู่"
  return
 if bar.value < 100.0 or elapsed < minimum_display_seconds:
  return
 ready_to_start = true
 status.text = "วันดี ๆ เริ่มต้นที่ริมน้ำ"
 percent.text = "พร้อมแล้ว"
 start_button.show()
 start_button.disabled = false
 if not require_start_input:
  _on_start_pressed()

func _unhandled_input(event: InputEvent) -> void:
 if ready_to_start and event.is_action_pressed("ui_accept"):
  get_viewport().set_input_as_handled()
  _on_start_pressed()

func _on_start_pressed() -> void:
 if not ready_to_start or _next_scene == null or _transitioning:
  return
 _transitioning = true
 start_button.disabled = true
 var instance := _next_scene.instantiate()
 if not instance is Control:
  instance.free()
  _transitioning = false
  _show_error()
  return
 menu_ui = instance as Control
 menu_ui.name = "MainMenuUI"
 menu_ui.modulate.a = 0.0
 add_child(menu_ui)
 $SafeArea.hide()
 $HeaderReadability.hide()
 ready_to_start = false
 set_process(false)
 create_tween().tween_property(menu_ui, "modulate:a", 1.0, 0.25)

func _show_error() -> void:
 failed = true
 ready_to_start = false
 status.text = "โหลดไม่สำเร็จ · แตะเพื่อลองอีกครั้ง"
 percent.text = ""
 start_button.hide()
 retry_button.show()

func _on_retry_pressed() -> void:
 failed = false
 requested = false
 ready_to_start = false
 _next_scene = null
 bar.value = 0.0
 status.text = "กำลังเตรียมบ่อตกปลา…"
 percent.text = "0%"
 retry_button.hide()
 _request_load()
