extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ",message)
 failures += int(not ok)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var path := "user://server-settings-test.cfg"
 check(SheetsConnectionSettings.valid_url(" https://script.google.com/macros/s/TEST/exec/ "), "HTTPS normalized")
 for address in ["http://example.com", "https://user:password@example.com", "https://example.com/path", "https://example.com?token=secret", "", "https://example.com\n.evil"]:
  check(not SheetsConnectionSettings.valid_url(address), "reject unsafe endpoint: " + address)
 check(SheetsConnectionSettings.resolve("https://script.google.com/macros/s/DEFAULT/exec",path) == "https://script.google.com/macros/s/DEFAULT/exec", "missing override uses packaged URL")
 check(SheetsConnectionSettings.save_url("https://script.google.com/macros/s/NEW/exec/",path) == OK, "save replacement URL")
 check(SheetsConnectionSettings.resolve("https://script.google.com/macros/s/OLD/exec",path) == "https://script.google.com/macros/s/NEW/exec", "saved endpoint survives reopening")
 check(SheetsConnectionSettings.save_url("http://wrong.example.com",path) != OK, "invalid update rejected")
 check(SheetsConnectionSettings.resolve("https://script.google.com/macros/s/OLD/exec",path) == "https://script.google.com/macros/s/NEW/exec", "invalid update preserves previous endpoint")
 check("URL" in SheetsConnectionSettings.failure_message(HTTPRequest.RESULT_CANT_RESOLVE,0), "DNS error explains changed URL")
 check("สิทธิ์" in SheetsConnectionSettings.failure_message(HTTPRequest.RESULT_SUCCESS,403), "auth error distinguished from network")
 var legacy_path := "user://legacy-endpoint-test.cfg"
 var legacy := ConfigFile.new()
 legacy.set_value("server","url","https://retired.example.com")
 legacy.save(legacy_path)
 check(SheetsConnectionSettings.resolve("https://script.google.com/macros/s/DEFAULT/exec","user://missing-setting.cfg",legacy_path).contains("/DEFAULT/"),"retired API override falls back to packaged Sheets URL")
 legacy.set_value("server","url","https://script.google.com/macros/s/LEGACY/exec")
 legacy.save(legacy_path)
 check(SheetsConnectionSettings.resolve("","user://missing-setting.cfg",legacy_path).contains("/LEGACY/"),"existing Sheets override survives settings migration")
 check(SheetsConnectionSettings.resolve("https://retired.example.com","user://missing-setting.cfg","user://missing-legacy.cfg").is_empty(),"invalid packaged endpoint is rejected")
 DirAccess.remove_absolute(legacy_path)
 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 root.add_child(panel)
 panel._open_connection_settings()
 check(panel.get_node("%EndpointOverlay").visible, "connection settings overlay opens")
 var identity: Dictionary = root.get_node("AnglerSave").data.identity.duplicate()
 panel.get_node("%Endpoint").text = "http://invalid"
 panel._save_endpoint()
 check(panel.get_node("%EndpointOverlay").visible, "invalid URL keeps dialog open")
 check(root.get_node("AnglerSave").data.identity == identity, "endpoint settings never change player identity")
 panel.close()
 check(not panel.get_node("%EndpointOverlay").visible, "back closes connection settings first")
 var had_override := FileAccess.file_exists(SheetsConnectionSettings.SAVE_PATH)
 var original := FileAccess.get_file_as_string(SheetsConnectionSettings.SAVE_PATH) if had_override else ""
 var profile: AnglerProfile = root.get_node("AnglerSave")
 var original_name: String = profile.data.identity.name
 profile.data.identity.name = ""
 panel._open_connection_settings()
 panel.get_node("%Endpoint").text = "https://script.google.com/macros/s/REPLACEMENT/exec/"
 panel._save_endpoint()
 check(panel.sheets_url == "https://script.google.com/macros/s/REPLACEMENT/exec", "UI applies replacement URL immediately")
 var reopened: Control = load("res://features/social/social_panel.tscn").instantiate()
 root.add_child(reopened)
 check(reopened.sheets_url == "https://script.google.com/macros/s/REPLACEMENT/exec", "reopened panel uses saved URL instead of obsolete packaged URL")
 reopened.queue_free()
 profile.data.identity.name = original_name
 if had_override:
  var file := FileAccess.open(SheetsConnectionSettings.SAVE_PATH, FileAccess.WRITE)
  file.store_string(original)
  file.close()
 else:
  DirAccess.remove_absolute(ProjectSettings.globalize_path(SheetsConnectionSettings.SAVE_PATH))
 panel.queue_free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("SHEETS SETTINGS RESULT: ",failures," failures")
 quit(1 if failures else 0)
