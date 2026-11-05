extends "res://tests/competition_test.gd"
# Replays real RemoteAngler with sparse poses; reports visual error, not transport latency.
func run() -> void:
 for scenario in ["straight", "stop_at_0.5s", "turn_at_0.5s"]:
  var peer = load("res://features/competition/remote_angler.tscn").instantiate()
  root.add_child(peer)
  peer.set_process(false)
  var actual := Vector3.ZERO
  var maximum := 0.0
  var total := 0.0
  var frames := 360
  for frame in frames:
   var t := float(frame)/60.0
   var v := Vector3(3,0,0)
   if t >= 0.5:
    if scenario == "stop_at_0.5s": v = Vector3.ZERO
    elif scenario == "turn_at_0.5s": v = Vector3(0,0,3)
   if frame % 120 == 0:
    peer.apply_pose({"p":[actual.x,actual.y,actual.z],"yaw":0,"speed":v.length(),"state":0,"v":[v.x,v.z]},"debug")
   actual += v / 60.0
   peer._process(1.0/60.0)
   var error: float = peer.global_position.distance_to(actual)
   maximum = maxf(maximum,error)
   total += error
  print("MOTION DEBUG ",scenario," max_error_m=",snappedf(maximum,0.01)," mean_error_m=",snappedf(total/frames,0.01))
  peer.queue_free()
 quit()
