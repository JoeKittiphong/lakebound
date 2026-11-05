extends "res://tests/competition_test.gd"
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.set_process(false)
 service.enabled=true
 service.profile.data.identity.name="นักตกปลา QA"
 service.room.clear()
 var panel: Control=load("res://features/competition/match_panel.tscn").instantiate()
 panel.auto_travel=false
 root.add_child(panel)
 panel.open()
 expect(panel.get_node("%Duration").item_count==5 and panel.get_node("%Duration").selected==2,"duration picker offers five choices and defaults to ten minutes")
 expect(panel.get_node("%Rule").item_count==3 and not panel.get_node("%Species").visible,"three modes offered; target picker hidden for all-species default")
 panel.get_node("%Map").select(1)
 panel.get_node("%Map").item_selected.emit(1)
 expect(panel.get_node("%Species").item_count==MatchRules.species_for("lotus_marsh").size(),"target picker only contains selected map's fish")
 panel.get_node("%Rule").select(0)
 panel.get_node("%Rule").item_selected.emit(0)
 expect(panel.get_node("%Species").visible,"species-total mode reveals target picker")
 panel.get_node("%Duration").select(4)
 panel.get_node("%Species").select(1)
 panel.get_node("%Create").pressed.emit()
 var item: Dictionary=service._queue.pop_front()
 expect(item.op=="create" and item.duration==1200 and item.rule=="species_total" and item.map=="lotus_marsh" and item.target_species==panel.get_node("%Species").get_item_metadata(1),"creation transmits selected duration, rule and map-valid target")
 panel.get_node("%Rule").select(2)
 panel.get_node("%Create").pressed.emit()
 item=service._queue.pop_front()
 expect(item.rule=="biggest_fish" and not item.has("target_species"),"biggest-fish mode does not transmit stale target")
 panel.get_node("%QuickJoin").pressed.emit()
 panel.get_node("%QuickJoin").pressed.emit()
 expect(service._queue.size()==1 and service._queue[0].op=="quick_join","quick-join clicks coalesce while queued")
 service._queue.clear()
 var room := fixture()
 room.rule="species_total";room.target_species="tilapia";room.duration=180
 expect(SERVICE.valid_snapshot(room) and MatchRules.description(room).begins_with("3 นาที"),"rule and selected duration bind to room description")
 expect(MatchRules.counts_species(room,"tilapia") and not MatchRules.counts_species(room,"snakehead"),"local scoring gate excludes non-target species")
 room.target_species="bluefin_tuna"
 expect(not SERVICE.valid_snapshot(room),"snapshot rejects target fish absent from map")
 room=fixture();room.duration=240
 expect(not SERVICE.valid_snapshot(room),"snapshot rejects unsupported round duration")
 for duration in MatchRules.DURATIONS:
  for rule in MatchRules.MODES:
   var wire_room := fixture()
   wire_room.duration=duration
   wire_room.rule=rule
   wire_room.target_species="tilapia" if rule=="species_total" else ""
   expect(SERVICE.valid_snapshot(JSON.parse_string(JSON.stringify(wire_room))),"JSON wire accepts duration %d with %s" % [duration,rule])
 for duration in [180.5,600.5,INF,NAN]:
  var bad_duration := fixture()
  bad_duration.duration=duration
  expect(not SERVICE.valid_snapshot(bad_duration),"fractional or nonfinite duration remains rejected")
 room=fixture();room.phase="running";room.starts_at=999;room.ends_at=1600
 service.room=room;service.connected=true;service._clock_server=1000;service._clock_ticks=Time.get_ticks_msec()
 var recorder=load("res://tests/fixtures/match_pose_recorder.gd").new()
 service.realtime=recorder
 service.send_pose(Vector3.ZERO,0,0,0)
 service.send_pose(Vector3.ONE,0,1,0)
 expect(recorder.poses.size()==1,"central pose limiter blocks sends closer than two seconds")
 service._last_pose_sent-=2000
 service._clock_ticks-=45001
 service.send_pose(Vector3.ONE,0,1,0)
 expect(recorder.poses.size()==1,"expired local lease stops realtime sends")
 service._clock_ticks=Time.get_ticks_msec();service.room.phase="lobby"
 service.send_pose(Vector3.ONE,0,1,0)
 expect(recorder.poses.size()==1,"lobby does not broadcast positions")
 service.forget_room()
 panel.queue_free()
 print("MATCH OPTIONS RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
