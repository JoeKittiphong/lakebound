extends "res://tests/competition_test.gd"
func run() -> void:
 root.get_node("Competition").enabled=false
 root.get_node("RankingOnline").enabled=false
 var auth: Node=root.get_node("AccountAuth")
 auth.enabled=true
 auth._offline_chosen=false
 expect(auth._switch_profile("offline",{}),"new account generation selects an independent offline save")
 var menu: Control=load("res://features/menu/main_menu_ui.tscn").instantiate()
 root.add_child(menu)
 current_scene=menu
 await process_frame
 await process_frame
 expect(menu.get_node("LoginPanel").visible and not menu.get_node("SocialPanel").visible,"fresh startup shows Google login before name entry")
 menu.get_node("LoginPanel/%Offline").pressed.emit()
 expect(not menu.get_node("LoginPanel").visible and auth._offline_chosen,"offline choice returns to menu")
 menu._on_competition_pressed()
 expect(menu.get_node("LoginPanel").visible and not menu.get_node("MatchPanel").visible,"competition always requires a Google account")
 menu.get_node("LoginPanel").close()
 menu._on_play_pressed()
 expect(menu.get_node("SocialPanel").visible,"offline fishing still supports local name setup")
 menu.get_node("SocialPanel").close()
 menu.queue_free()
 await process_frame
 print("GOOGLE STARTUP RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
