extends "res://features/auth/account_auth.gd"
var responses: Array=[]
var calls: Array=[]
func _http(path: String, body: Dictionary, authenticated_request := false) -> Dictionary:
 calls.append({"path":path,"body":body.duplicate(true),"authenticated":authenticated_request})
 await get_tree().process_frame
 return responses.pop_front() if not responses.is_empty() else {"error":"network_error"}
func _save_session() -> void: pass
