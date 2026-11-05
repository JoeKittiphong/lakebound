extends MatchRealtime
var poses: Array=[]
func _init() -> void:
 joined=true
func send_pose(value: Dictionary) -> void:
 poses.append(value.duplicate(true))
