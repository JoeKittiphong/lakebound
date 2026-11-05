extends Node
var _identity: String
var room: Dictionary
func member(id: String) -> Dictionary:
 for row in room.members:
  if row.id==id:return row
 return {}
