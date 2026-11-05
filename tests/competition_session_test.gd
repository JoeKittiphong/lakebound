extends "res://tests/competition_test.gd"
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false
 root.get_node("RankingOnline").enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.data.identity.name="นักตกปลา QA"
 service._identity=profile.data.identity.id
 var before := JSON.stringify(profile.data)
 var collection: Node=root.get_node("FishCollection")
 var records_before := JSON.stringify(collection.records)
 service.room=fixture()
 service.room.phase="loading"
 service._clock_server=1000.0
 service._clock_ticks=Time.get_ticks_msec()
 var game: Node3D=load("res://features/regions/lotus_marsh.tscn").instantiate()
 root.add_child(game)
 current_scene=game
 game.get_node("FishingEffects").audio_enabled=false
 await process_frame
 var session: Node=game.get_node("MatchSession")
 expect(session.active and not game.economy_enabled and game.profile==null,"competition bypasses persistent economy")
 expect(not game.fishing.casting_enabled and not game.fishing.cast(),"cast blocked during loading")
 expect(not game.hud.is_tutorial_active(),"competition does not start or save tutorial")
 expect(game.fishing.active_bait_item().id==&"worm","competition uses owned equipped bait")
 game._on_configuration_changed(&"lure",1.0)
 expect(not game.fishing.using_lure(),"configuration cannot bypass owned equipped bait")
 expect(profile.shopping_locked and not profile.buy("worm"),"competition rejects in-game purchases")
 game.hud.open_tackle()
 expect(game.hud.get_node("TacklePanel/Shop").inventory_only,"competition opens owned-only equipment bag")
 game.hud.close_top_panel()
 game._on_configuration_changed(&"worm",1.0)
 service.room.phase="running"
 service.room.starts_at=999
 service.room.ends_at=1600
 service.connected=true
 await process_frame
 expect(game.fishing.casting_enabled and game.player.input_enabled,"shared start enables gameplay")
 game._on_collection_visibility_changed(true)
 expect(not paused,"opening a modal cannot pause match time")
 game._on_collection_visibility_changed(false)
 var caught: FishState=game.pond.fish[0]
 caught.weight=1.234
 game.fishing.active_fish=caught
 game.fishing.state=FishingController.State.RESULT
 session._fish_claim={"fish_id":caught.id,"claim_id":"10000000-0000-4000-8000-000000000001","player_id":service._identity,"round_id":service.room.round_id,"expires_at":1600}
 service.enabled=true
 game._on_fish_landed(caught)
 service.enabled=false
 expect(service._queue.size()==1 and service._queue[0].op=="catch" and service._queue[0].grams==1234,"landed fish enters authoritative score queue in integer grams")
 game._on_fish_landed(caught)
 expect(service._queue.size()==1,"repeated landing callback cannot duplicate score")
 expect(game.hud.get_node("SafeArea/BagDock").records.size()==1,"competition catch appears once in session fish slots")
 expect(JSON.stringify(profile.data)==before and JSON.stringify(collection.records)==records_before,"match catch cannot change main save or collection")
 service._queue.clear()
 session._pose({"id":"a".repeat(32),"p":[0,1,0],"yaw":0,"speed":2,"state":0,"seq":1})
 expect(session.peers.size()==1,"remote player spawns from editable scene")
 if DisplayServer.get_name()!="headless":
  var point: Vector3=game.player.global_position+Vector3(2,0,-2)
  session._pose({"id":"a".repeat(32),"p":[point.x,point.y,point.z],"yaw":0,"speed":0,"state":0,"seq":2})
  for i in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-competition/gameplay.png")
 service._clock_server=1601
 await process_frame
 await process_frame
 expect(not game.fishing.casting_enabled and not game.player.input_enabled,"deadline stops fishing and movement")
 service.room.phase="finished"
 service.changed.emit()
 await process_frame
 expect(game.get_node("MatchHUD/MatchPanel").visible,"final snapshot opens results")
 expect(JSON.stringify(profile.data)==before,"whole round preserves original profile")
 service.room.phase="lobby"
 service.room.round_id="00000000-0000-4000-8000-000000000003"
 service.changed.emit()
 await process_frame
 expect(game.get_node("MatchHUD/MatchPanel").visible and session._landed.is_empty(),"rematch resets local round and keeps lobby open")
 service.room.phase="loading"
 service.changed.emit()
 await process_frame
 expect(not game.get_node("MatchHUD/MatchPanel").visible,"next round closes lobby so it cannot block fishing")
 game.get_node("MatchHUD").set_process(false)
 session.set_process(false)
 service.room.clear()
 game.queue_free()
 session.peers.clear()
 caught=null
 await process_frame
 print("COMPETITION SESSION RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
