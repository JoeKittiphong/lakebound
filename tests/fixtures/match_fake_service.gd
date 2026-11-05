extends "res://features/competition/match_service.gd"
var responses: Array=[]
var calls: Array[Dictionary]=[]
func _http(path: String, body: Dictionary, authenticated := false) -> Dictionary:
 calls.append({"path":path,"body":body.duplicate(true),"authenticated":authenticated})
 await get_tree().process_frame
 # Match the real HTTP decoder, including float-valued JSON numbers.
 return JSON.parse_string(JSON.stringify(responses.pop_front())) if not responses.is_empty() else {"error":"network_error"}
func _save_session() -> void: pass
