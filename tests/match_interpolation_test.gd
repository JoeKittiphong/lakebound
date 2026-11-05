extends "res://tests/competition_test.gd"
func pose(x: float, movement := 3.0, yaw := 0.0) -> Dictionary:
 return {"p":[x,0,0],"yaw":yaw,"speed":movement,"state":0,"v":[movement,0]}
func advance(peer: Node, seconds: float, fps := 60) -> void:
 for i in int(round(seconds*fps)): peer._process(1.0/fps)
func replay(scenario: String, fps: int, jitter: bool) -> float:
 var peer=load("res://features/competition/remote_angler.tscn").instantiate()
 root.add_child(peer);peer.set_process(false)
 var actual:=Vector3.ZERO
 var pending: Array[Dictionary]=[]
 var maximum:=0.0
 var next_send:=0.0
 var sent:=0
 for frame in fps*6:
  var t:=float(frame)/fps
  var v:=Vector3(3,0,0)
  if t>=0.5:
   if scenario=="stop": v=Vector3.ZERO
   elif scenario=="turn": v=Vector3(0,0,3)
  if t>=next_send:
   next_send=t+0.334
   sent+=1
   if not jitter or sent%7!=0:
    pending.append({"at":t+(0.04 if sent%2==0 else 0.12) if jitter else t,"pose":{"p":[actual.x,0,actual.z],"yaw":0,"speed":v.length(),"state":0,"v":[v.x,v.z]}})
  while not pending.is_empty() and float(pending[0].at)<=t:
   peer.apply_pose(pending.pop_front().pose,"QA")
  actual+=v/fps
  peer._process(1.0/fps)
  if t>0.3: maximum=maxf(maximum,peer.global_position.distance_to(actual))
 peer.queue_free()
 return maximum
func run() -> void:
 var peer=load("res://features/competition/remote_angler.tscn").instantiate()
 root.add_child(peer);peer.set_process(false)
 peer.apply_pose(pose(0,0),"QA")
 advance(peer,6)
 peer.apply_pose(pose(0),"QA")
 for i in 6:
  advance(peer,0.35)
  peer.apply_pose(pose((i+1)*1.05),"QA")
 var before: float=peer.global_position.x
 advance(peer,0.35)
 expect(absf(peer.global_position.x-before-1.05)<0.1,"after idle, regular walking stays at three metres per second")
 peer.apply_pose(pose(100,0,deg_to_rad(170)),"QA")
 expect(is_equal_approx(peer.global_position.x,100),"teleport clears old playback")
 peer.apply_pose(pose(100,0,deg_to_rad(-170)),"QA")
 advance(peer,0.4)
 expect(absf(peer.rotation.y)>2.9,"yaw crosses PI by short arc")
 peer.apply_pose(pose(100),"QA")
 advance(peer,3)
 expect(peer.global_position.x<101.36 and peer.speed==0,"loss stops prediction within 0.45 seconds")
 advance(peer,11)
 expect(not peer.visible,"stale avatar hidden")
 peer.apply_pose(pose(105,0),"QA")
 expect(peer.visible and is_equal_approx(peer.global_position.x,105),"reconnect resets stale playback")
 for i in 50: peer.apply_pose(pose(105,0),"QA")
 advance(peer,0.1)
 expect(peer._samples.size()<=16 and is_finite(peer.global_position.x),"burst samples bounded and finite")
 for fps in [30,60,120]:
  for scenario in ["straight","stop","turn"]:
   var error:=replay(scenario,fps,false)
   print("MOTION error_m=",error," scenario=",scenario," fps=",fps)
   expect(error<1.7,"normal packet replay bounds error: %s %d FPS" % [scenario,fps])
   error=replay(scenario,fps,true)
   expect(error<2.1,"jitter and packet loss replay bounds error: %s %d FPS" % [scenario,fps])
 var service: Node=root.get_node("Competition")
 service.enabled=false;service.room=fixture()
 service.room.pose_interval=0.334
 expect(SERVICE.valid_snapshot(JSON.parse_string(JSON.stringify(service.room))),"fast room policy survives JSON")
 expect(is_equal_approx(service.pose_interval(),0.334),"central limiter uses server policy")
 var recorder=load("res://tests/fixtures/match_pose_recorder.gd").new()
 service.realtime=recorder
 service.room.phase="running";service.room.starts_at=999;service.room.ends_at=1600
 service.connected=true;service._clock_server=1000;service._clock_ticks=Time.get_ticks_msec()
 service._last_pose_sent=Time.get_ticks_msec()-333
 expect(not service.send_pose(Vector3.ZERO,0,3,0,Vector3(3,0,0)),"333 ms remains rate limited")
 service._last_pose_sent=Time.get_ticks_msec()-334
 expect(service.send_pose(Vector3.ZERO,0,3,0,Vector3(3,0,0)) and recorder.poses.size()==1,"334 ms movement update accepted")
 expect(not service.send_pose(Vector3.ZERO,0,0,0),"stop cannot bypass central rate budget")
 service._last_pose_sent=Time.get_ticks_msec()-334
 service._last_broadcast_pose=service._last_pose_sent
 expect(service.send_pose(Vector3.ZERO,0,0,0) and recorder.poses.back().speed==0,"stop at same position sends on next allowed tick")
 service._last_pose_sent=Time.get_ticks_msec()-334
 service._last_broadcast_pose=service._last_pose_sent
 recorder.joined=false
 var sent_at: int=service._last_pose_sent
 expect(not service.send_pose(Vector3.ZERO,0,0,0) and service._last_pose_sent==sent_at,"connecting socket cannot consume an unsent pose")
 recorder.joined=true
 expect(service.send_pose(Vector3.ZERO,0,0,0),"channel join immediately retries pending pose")
 service.room.pose_interval=0.01
 expect(not SERVICE.valid_snapshot(service.room) and service.pose_interval()>=0.334,"cannot lower policy below local safe rate")
 service.room.pose_interval=2.0
 expect(is_equal_approx(service.pose_interval(),2),"legacy rooms preserve reserved slow policy")
 service.room.clear()
 var session=load("res://features/competition/match_session.gd").new()
 session._last_pose_position=Vector3.ZERO;session._last_pose_yaw=0;session._last_pose_state=0;session._last_pose_speed=3
 expect(session._pose_changed(Vector3.ZERO,0,0,0),"session detects stop even without position or yaw change")
 session._last_pose_speed=0
 expect(not session._pose_changed(Vector3.ZERO,0,0,0),"stationary session avoids unnecessary traffic")
 session._idle_clock=6
 expect(session._pose_changed(Vector3.ZERO,0,0,0),"idle heartbeat remains available")
 session.free()
 peer.queue_free()
 print("INTERPOLATION RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
