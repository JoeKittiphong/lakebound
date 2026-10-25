extends PanelContainer

signal claim_requested(id: String)
signal track_requested(id: String)
var mission_id := ""

func bind(definition: MissionDefinition, state: Dictionary, available: bool) -> void:
 mission_id = definition.id
 var entry := MissionProgress.entry(state, definition)
 var complete := MissionProgress.completed(state, definition)
 $Content/Header/Title.text = definition.title
 $Content/Description.text = definition.description
 $Content/Progress.max_value = definition.target
 $Content/Progress.value = entry.progress
 $Content/Footer/Status.text = "%s   ·   %d เหรียญ" % [MissionProgress.progress_text(state, definition), definition.reward_coins]
 $Content/Header/Badge.text = "รับแล้ว" if entry.claimed else ("สำเร็จ" if complete else "กำลังทำ")
 $Content/Footer/Claim.text = "รับแล้ว" if entry.claimed else "รับรางวัล"
 $Content/Footer/Claim.disabled = not available or not complete or entry.claimed
 $Content/Footer/Track.text = "เลิกติดตาม" if state.tracked == mission_id else "ติดตาม"
 $Content/Footer/Track.disabled = not available or entry.claimed

func _on_claim() -> void:
 claim_requested.emit(mission_id)

func _on_track() -> void:
 track_requested.emit(mission_id)
