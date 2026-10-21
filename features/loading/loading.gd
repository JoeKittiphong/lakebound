extends Control
@export_file("*.tscn") var next_scene_path: String = "res://features/menu/main_menu.tscn"
@export_range(0.0, 8.0) var minimum_display_seconds: float = 2.5
@onready var bar: ProgressBar = $SafeArea/LoadPanel/Content/SwimmingProgress/ProgressBar
@onready var status: Label = $SafeArea/LoadPanel/Content/StatusRow/Status
@onready var percent: Label = $SafeArea/LoadPanel/Content/StatusRow/Percent
var elapsed := 0.0
var requested := false
var failed := false

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
  get_tree().quit()

func _ready() -> void:
 var error := ResourceLoader.load_threaded_request(next_scene_path)
 requested = error == OK
 if not requested:
  _show_error()

func _process(delta: float) -> void:
 if not requested or failed:
  return
 elapsed += delta
 var progress: Array = []
 var state := ResourceLoader.load_threaded_get_status(next_scene_path, progress)
 if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
  _show_error()
  return
 var actual: float = float(progress[0]) if not progress.is_empty() else 0.0
 var target: float = minf(actual * 100.0, elapsed / maxf(minimum_display_seconds, 0.01) * 100.0)
 bar.value = move_toward(bar.value, target, delta * 90.0)
 percent.text = "%d%%" % int(bar.value)
 if state == ResourceLoader.THREAD_LOAD_LOADED:
  status.text = "พร้อมออกเดินทาง" if bar.value >= 99.0 else "เตรียมบ่อตกปลา…"
  if bar.value >= 100.0:
   set_process(false)
   var packed := ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
   get_tree().change_scene_to_packed(packed)

func _show_error() -> void:
 failed = true
 status.text = "โหลดไม่สำเร็จ — กดปุ่มลองอีกครั้ง"
 $SafeArea/LoadPanel/Content/RetryButton.show()

func _on_retry_pressed() -> void:
 get_tree().reload_current_scene()
