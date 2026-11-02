extends SceneTree
var failures := 0

func check(value: bool, label: String) -> void:
 print("PASS: " if value else "FAIL: ", label)
 failures += int(not value)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 check(AnglerIdentity.valid_name("นักตกปลาริมน้ำ"), "Thai name")
 check(not AnglerIdentity.valid_name(" ") and not AnglerIdentity.valid_name("x\ny") and not AnglerIdentity.valid_name("[name]"), "invalid names")
 var profile := AnglerProfile.new()
 profile.save_path = "user://social-test.cfg"
 profile.data = profile.defaults()
 var identity: String = profile.data.identity.id
 check(profile.set_display_name("  ทดสอบ  "), "save name")
 profile.load_profile()
 check(profile.data.identity.id == identity and profile.data.identity.name == "ทดสอบ", "reload stable identity")
 var config := ConfigFile.new()
 var legacy := profile.defaults()
 legacy.erase("identity")
 config.set_value("meta", "version", 1)
 config.set_value("profile", "data", legacy)
 config.save("user://social-legacy.cfg")
 var migrated := ProfileStore.load_profile("user://social-legacy.cfg")
 check(not migrated.incompatible and AnglerIdentity.valid(migrated.data.identity), "legacy migration")
 var records := [{"player_id":"a", "weight": 3.0,"time": 2,"map":"river","species":"tilapia"}, {"player_id":"a", "weight": 5.0,"time": 4,"map":"lotus_marsh","species":"tilapia"}, {"player_id":"b", "weight": 5.0,"time": 3,"map":"river","species":"snakehead"}]
 var overall := AnglerIdentity.best(records)
 check(overall.size() == 2 and overall[0].player_id == "b", "best per player and earlier tie")
 check(AnglerIdentity.best(records,"map","river").size() == 2, "map filter")
 check(AnglerIdentity.best(records,"species","tilapia").size() == 1, "species filter")
 check(AnglerIdentity.best(records,"species","absent").is_empty(), "empty filter")
 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 root.add_child(panel)
 panel.sheets_url = ""
 panel.open()
 check(panel.visible and panel.get_node("%Mode").item_count == 2, "panel authored and opened")
 panel._mode_changed(1)
 check(panel.get_node("%Filter").item_count == 6, "all map choices")
 panel.queue_free()
 var session: AnglerProfile = root.get_node("AnglerSave")
 session.data = session.defaults()
 var menu: Control = load("res://features/menu/main_menu_ui.tscn").instantiate()
 root.add_child(menu)
 await process_frame
 check(menu.get_node("SocialPanel").visible, "new player naming screen opens from main menu")
 menu.get_node("SocialPanel").close()
 check(menu.get_node("SocialPanel").visible, "cannot skip required name")
 menu.get_node("SocialPanel").hide()
 menu._on_play_pressed()
 check(menu.get_node("SocialPanel").visible, "play requires a name")
 menu.queue_free()
 profile.free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path("user://social-test.cfg"))
 DirAccess.remove_absolute(ProjectSettings.globalize_path("user://social-legacy.cfg"))
 print("SOCIAL PROFILE RESULT: ", failures, " failures")
 quit(1 if failures else 0)

