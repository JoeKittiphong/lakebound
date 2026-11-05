extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 failures += int(not ok)
 print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
 # No catches and no registration: only a public map read against production.
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.data.identity.name = "Background HTTP QA"
 var service: Node = root.get_node("RankingOnline")
 service.enabled = false
 service.bind_profile(profile)
 service.enabled = true
 service.watch_map("river")
 for i in 3: await process_frame
 var deadline := Time.get_ticks_msec()+30000
 while service.busy and Time.get_ticks_msec()<deadline: await process_frame
 var state: Dictionary = service.leader_state("river")
 check(state.loaded and not state.get("cached",false),"persistent service reads a fresh real Supabase map leader")
 check(service.sync.read_only and service.sync.acknowledged_name.is_empty(),"background map fetch never registers or uploads QA profile")
 var badge: Button = load("res://features/social/map_leader_badge.tscn").instantiate()
 root.add_child(badge)
 badge.bind(service,"river")
 if state.loaded and not state.record.is_empty():
  check(badge.get_node("Content/Player").text==str(state.record.player_name),"badge binds the real map leader without opening ranking")
  check(badge.get_node("Content/Weight").text=="%.3f กก."%float(state.record.weight),"badge binds real leader weight")
 service.enabled = false
 badge.queue_free()
 print("BACKGROUND LIVE RESULT: %d failures"%failures)
 quit(1 if failures else 0)
