extends Control
var selected_region := "river"
@export var privacy_policy_url: String = "https://zylaah-support.netlify.app/privacy"

func _ready() -> void:
 _select_region(str(get_tree().get_meta("selected_region", "river")))
 if AnglerSave.data.identity.name.is_empty():
  $SocialPanel.open.call_deferred()
func _select_region(id: String) -> void:
 var entry := RegionCatalog.find(id)
 selected_region = entry.id
 $SafeArea/PlayCard/Content/MapCarousel.set_region(selected_region)
 get_tree().set_meta("selected_region", selected_region)
 $SafeArea/PlayCard/Content/Location.text = entry.name
 $SafeArea/PlayCard/Content/Description.text = entry.subtitle
 $SafeArea/PlayCard/Content/Build.text = "ปลา %d รายการ · ภารกิจ %d รายการ" % [entry.fish_count,entry.mission_count]
func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
  if $SocialPanel.visible:
   $SocialPanel.close()
  else:
   get_tree().quit()

func _on_play_pressed() -> void:
 if AnglerSave.data.identity.name.is_empty():
  $SocialPanel.open()
  return
 $SafeArea/PlayCard/Content/PlayButton.disabled = true
 $SafeArea/PlayCard/Content/PlayButton.text = "กำลังเดินทาง..."
 # Keep only the path across the transition. Loading the map here keeps the
 # cinematic, menu textures and map resources resident at the same time.
 get_tree().set_meta("pending_map_scene", str(RegionCatalog.find(selected_region).scene))
 var error := get_tree().change_scene_to_file("res://features/loading/map_transition.tscn")
 if error != OK:
  $SafeArea/PlayCard/Content/PlayButton.disabled = false
  $SafeArea/PlayCard/Content/PlayButton.text = "ลองเข้าแหล่งน้ำอีกครั้ง"

func _on_privacy_pressed() -> void:
 var result := OS.shell_open(privacy_policy_url)
 $SafeArea/PrivacyButton.tooltip_text = "เปิดในเบราว์เซอร์" if result == OK else privacy_policy_url
