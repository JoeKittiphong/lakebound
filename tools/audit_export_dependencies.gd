extends SceneTree
var records = {}
func _initialize():
	scan("res://")
	var f = FileAccess.open("res://exports/cleanup-qa/godot-dependencies.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(records))
	print("DEPENDENCY AUDIT: ",records.size()," resources")
	quit()
func scan(path: String):
	var dir = DirAccess.open(path)
	if not dir: return
	for name in dir.get_directories():
		if name.begins_with(".") or name in ["android","signing","exports","docs","tools","tests","server","services","export_templates","feature_profiles","script_templates","text_editor_themes","fishing-game"]:continue
		scan(path.path_join(name))
	for name in dir.get_files():
		if not name.ends_with(".import") and not name.ends_with(".uid") and ResourceLoader.exists(path.path_join(name)):
			var file = path.path_join(name)
			records[file] = Array(ResourceLoader.get_dependencies(file))
