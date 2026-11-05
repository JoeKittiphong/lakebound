extends SceneTree
# Run with --main-pack exports/web/index.pck and an isolated APPDATA directory.
func _initialize() -> void:
 call_deferred("check_pack")

func check_pack() -> void:
 for path in ["res://features/auth/account_auth.gd", "res://features/auth/web_oauth.gd", "res://features/auth/oauth_pkce.gd", "res://features/social/supabase_connection_settings.gd", "res://features/competition/match_row.tscn"]:
  if not ResourceLoader.exists(path) or load(path)==null:
   push_error("WEB PACK MISSING: "+path)
   quit(1)
   return
 var scene=load("res://features/menu/main_menu_ui.tscn")
 if scene==null: quit(1); return
 var menu=scene.instantiate()
 root.add_child(menu)
 await process_frame
 var auth=root.get_node("AccountAuth")
 var panel=menu.get_node("LoginPanel")
 var button=panel.get_node("%Google")
 if auth.get("status")==null or button.pressed.get_connections().is_empty():
  push_error("WEB PACK: auth script or login signal failed")
  quit(1)
  return
 print("WEB PACK PASS: auth dependencies, menu scripts and Google signal are present")
 quit()
