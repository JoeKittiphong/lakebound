extends SceneTree
const PEER=preload("res://pose_peer.gd")
var failures:=0
var checks:=0
func _initialize() -> void: run.call_deferred()
func expect(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1
 print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
 var links: Array=[]
 # Complete five-player mesh: 10 independent links / 20 actual peer connections.
 for a in 5:
  for b in range(a+1,5):
   var one=PEER.new();var two=PEER.new()
   if one.initialize()!=OK or two.initialize()!=OK:
    expect(false,"official native extension initializes");quit(1);return
   one.description_ready.connect(two.accept_description);two.description_ready.connect(one.accept_description)
   one.candidate_ready.connect(two.accept_candidate);two.candidate_ready.connect(one.accept_candidate)
   links.append([one,two]);one.connection.create_offer()
 var deadline:=Time.get_ticks_msec()+15000
 while Time.get_ticks_msec()<deadline:
  var ready:=0
  for pair in links:
   pair[0].poll();pair[1].poll()
   if pair[0].channel.get_ready_state()==WebRTCDataChannel.STATE_OPEN and pair[1].channel.get_ready_state()==WebRTCDataChannel.STATE_OPEN: ready+=1
  if ready==10: break
  await process_frame
 expect(links.all(func(pair): return pair[0].channel.get_ready_state()==WebRTCDataChannel.STATE_OPEN and pair[1].channel.get_ready_state()==WebRTCDataChannel.STATE_OPEN),"five-player mesh opens all ten DataChannels")
 var pose:={"id":"a".repeat(32),"p":[1,0,2],"yaw":0,"speed":3,"state":0,"seq":1}
 for pair in links:
  expect(pair[0].send_pose(pose)==OK and pair[1].send_pose(pose)==OK,"bidirectional real pose packets accepted")
 deadline=Time.get_ticks_msec()+3000
 while Time.get_ticks_msec()<deadline:
  for pair in links: pair[0].poll();pair[1].poll()
  if links.all(func(pair): return pair[0].received==1 and pair[1].received==1): break
  await process_frame
 expect(links.all(func(pair): return pair[0].received==1 and pair[1].received==1),"all ten links deliver real packets in both directions")
 for pair in links: pair[0].send_pose(pose)
 for i in 30:
  for pair in links: pair[0].poll();pair[1].poll()
  await process_frame
 expect(links.all(func(pair): return pair[1].received==1),"duplicate sequences are discarded")
 var invalid:=pose.duplicate(true);invalid.p=[INF,0,0]
 expect(not PEER.valid_pose(invalid),"nonfinite positions rejected")
 invalid=pose.duplicate(true);invalid.seq=1.5
 expect(not PEER.valid_pose(invalid),"fractional sequences rejected")
 invalid=pose.duplicate(true);invalid.id="bad"
 expect(not PEER.valid_pose(invalid),"malformed sender rejected")
 for pair in links:
  pair[0].close();pair[1].close()
 expect(links[0][0].send_pose(pose)==ERR_UNCONFIGURED,"closed channel cannot send")
 print("NATIVE WEBRTC RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
