extends Control
const PEER=preload("res://pose_peer.gd")
var peers: Array=[]
var elapsed:=0.0
var tick:=0.0
var sequence:=0

func _run() -> void:
 for p in peers: p.close()
 peers=[PEER.new(),PEER.new()]
 for p in peers:
  if p.initialize()!=OK:
   $Margin/Column/Status.text="WebRTC extension unavailable. Run setup-native.ps1 first."
   return
 for i in 2:
  var other=peers[1-i]
  peers[i].description_ready.connect(func(kind: String,sdp: String): other.accept_description(kind,sdp))
  peers[i].candidate_ready.connect(func(mid: String,index: int,candidate: String): other.accept_candidate(mid,index,candidate))
 peers[0].connection.create_offer()
 elapsed=0;tick=0;sequence=0

func _process(delta: float) -> void:
 if peers.size()!=2 or peers[0].connection==null or peers[1].connection==null: return
 elapsed+=delta;tick+=delta
 for p in peers: p.poll()
 if tick>=0.05:
  tick=0;sequence+=1
  for i in 2:
   peers[i].send_pose({"id":str(i+1).repeat(32),"p":[sin(elapsed)*3,0,cos(elapsed)*3],"yaw":0,"speed":3,"state":0,"seq":sequence})
 var open: bool=peers[0].channel.get_ready_state()==WebRTCDataChannel.STATE_OPEN and peers[1].channel.get_ready_state()==WebRTCDataChannel.STATE_OPEN
 $Margin/Column/Status.text="DataChannel: %s\nA sent/received: %d / %d\nB sent/received: %d / %d\nActual local WebRTC; in-memory signaling; no Supabase messages.\nTURN and cross-device routing are not verified by this local test." % ["OPEN" if open else "CONNECTING",peers[0].sent,peers[0].received,peers[1].sent,peers[1].received]

func _exit_tree() -> void:
 for p in peers: p.close()
 peers.clear()
