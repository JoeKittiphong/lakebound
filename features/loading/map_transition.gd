extends Control

var target_path: String
var loading := false

func _ready() -> void:
 target_path = str(get_tree().get_meta("pending_map_scene", ""))
 # change_scene frees the old scene at the end of the frame. Wait until its
 # nodes and rendering resources can be released before requesting the map.
 await get_tree().process_frame
 await get_tree().process_frame
 _request_map()

func _request_map() -> void:
 if loading:
  return
 loading = true
 $Center/Content/Retry.hide()
 $Center/Content/Back.hide()
 $Center/Content/Status.text = "กำลังโหลดแหล่งน้ำ…"
 # Draw the lightweight screen before loading on the main thread. Map shaders
 # share rendering resources; do not load them on a worker during scene teardown.
 await get_tree().process_frame
 if target_path.is_empty() or not ResourceLoader.exists(target_path):
  _show_error()
  return
 var scene := ResourceLoader.load(target_path) as PackedScene
 if scene == null or get_tree().change_scene_to_packed(scene) != OK:
  _show_error()

func _show_error() -> void:
 loading = false
 $Center/Content/Status.text = "โหลดแหล่งน้ำไม่สำเร็จ · ลองอีกครั้ง"
 $Center/Content/Retry.show()
 $Center/Content/Back.show()

func _on_back_pressed() -> void:
 get_tree().change_scene_to_file("res://features/menu/main_menu.tscn")
