class_name CatchResult
extends Control

signal keep_requested
signal release_requested

func present(fish: FishState, save_error: String = "") -> void:
 $Card/Content/FishName.text = fish.species.display_name
 $Card/Content/Weight.text = "%.2f กก." % fish.weight
 $Card/Content/Description.text = "บันทึกแล้ว" if save_error.is_empty() else save_error
 $Card/Content/Preview/Viewport/Fish.setup(fish)
 $Card/Content/Preview/Viewport/Fish.configure_preview(true)

func set_open(value: bool) -> void:
 visible = value
 if not value:
  $Card/Content/Preview/Viewport/Fish.set_process(false)
  $Card/Content/Preview/Viewport/Fish.set_animation_active(false)

func _on_keep_pressed() -> void:
 keep_requested.emit()

func _on_release_pressed() -> void:
 release_requested.emit()
