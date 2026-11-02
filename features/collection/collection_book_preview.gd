extends Control
## Standalone art/animation review scene. Collection data is connected in a later stage.
@onready var viewport: SubViewport = $Preview/Viewport
@onready var animation: AnimationPlayer = $Preview/Viewport/Stage/Book.find_child("AnimationPlayer", true, false)
@onready var status: Label = $Status
var state := "closed"
var _destination := "closed"

func _ready() -> void:
	animation.animation_finished.connect(_finished)
	animation.play("OpenBook")
	animation.seek(0.0, true)
	animation.pause()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sync_buttons()

func _play(clip: StringName, reverse: bool, destination: String) -> void:
	if state == "busy": return
	state = "busy"
	_destination = destination
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if reverse: animation.play_backwards(clip)
	else: animation.play(clip)
	_sync_buttons()

func _finished(_clip: StringName) -> void:
	state = _destination
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sync_buttons()

func _sync_buttons() -> void:
	$Actions/Open.disabled = state != "closed"
	$Actions/Next.disabled = state != "open"
	$Actions/Previous.disabled = state != "open"
	$Actions/Close.disabled = state != "open"
	status.text = "กำลังเคลื่อนไหว…" if state == "busy" else "พร้อมเปิดเล่ม" if state == "closed" else "กางแล้ว · ทดลองพลิกหน้าได้"

func _on_open() -> void: _play("OpenBook", false, "open")
func _on_next() -> void: _play("TurnPage", false, "open")
func _on_previous() -> void: _play("TurnPage", true, "open")
func _on_close() -> void: _play("OpenBook", true, "closed")
