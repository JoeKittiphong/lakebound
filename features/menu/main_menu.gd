extends Control
@export var gameplay_scene: PackedScene
@export var privacy_policy_url: String = "https://zylaah-support.netlify.app/privacy"

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
  get_tree().quit()

func _on_play_pressed() -> void:
 $SafeArea/PlayCard/Content/PlayButton.disabled = true
 get_tree().change_scene_to_packed(gameplay_scene)

func _on_privacy_pressed() -> void:
 var result := OS.shell_open(privacy_policy_url)
 $SafeArea/PrivacyButton.tooltip_text = "เปิดในเบราว์เซอร์" if result == OK else privacy_policy_url
