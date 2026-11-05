extends "res://tests/competition_test.gd"
const RTC=preload("res://features/competition/match_webrtc.gd")
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 service._identity=profile.data.identity.id
 var room:=fixture()
 room.pose_interval=0.334
 var ids: Array=[service._identity,room.members[1].id,"3".repeat(32),"4".repeat(32),"5".repeat(32)]
 for i in range(2,5):
  var member: Dictionary=room.members[1].duplicate(true);member.id=ids[i];room.members.append(member)
 var controllers: Array=[]
 var stubs: Array=[]
 for i in 5:
  var stub=load("res://tests/fixtures/rtc_service_stub.gd").new();stub._identity=ids[i];stub.room=room;stubs.append(stub)
  var c=load("res://features/competition/match_webrtc.tscn").instantiate();root.add_child(c);c.set_process(false)
  c.service=stub;c.enabled=true;c._opened=true;c._room=room.id;c._round=room.round_id;c._session=str(i+1).repeat(32);c._ice_until=Time.get_unix_time_from_system()+3600
  controllers.append(c)
 var roster: Array=[]
 for i in 5:roster.append({"player_id":ids[i],"session_id":str(i+1).repeat(32)})
 for c in controllers:c._apply_roster(roster)
 var deadline:=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  for i in 5:
   for l in controllers[i].links.values():l.peer.poll()
   while not controllers[i]._outbox.is_empty():
    var m: Dictionary=controllers[i]._outbox.pop_front()
    var target: int=ids.find(m.to)
    var peer=controllers[target].links[ids[i]].peer
    if m.kind in ["offer","answer"]:peer.accept_description(m.kind,m.data)
    else:peer.accept_candidate(m.data.mid,int(m.data.index),m.data.candidate)
  if controllers.all(func(c):return c.all_ready()):break
  await process_frame
 expect(controllers.all(func(c):return c.all_ready()),"five-player mesh opens all twenty directed native DataChannels")
 var accepted: Array=[]
 controllers[1].pose_received.connect(func(value: Dictionary):accepted.append(value))
 var packet:={"id":ids[0],"p":[1,0,2],"yaw":0,"speed":3,"state":0,"seq":1,"v":[3,0],"round":room.round_id}
 expect(controllers[0].send_pose(packet)==4,"game sends actual pose to four authenticated peers through WebRTC")
 for i in 30:
  controllers[1].links[ids[0]].peer.poll();await process_frame
 expect(accepted.size()==1,"authenticated link forwards valid remote pose")
 packet.id=ids[1];packet.seq=2;controllers[0].send_pose(packet)
 for i in 30:
  controllers[1].links[ids[0]].peer.poll();await process_frame
 expect(accepted.size()==1,"link rejects packet impersonating another room member")
 var original: Node=service.rtc
 service.rtc=controllers[0];service.room=room;service.room.phase="running";service.room.starts_at=999;service.room.ends_at=1600;service.connected=true;service._clock_server=1000;service._clock_ticks=Time.get_ticks_msec()
 var recorder=load("res://tests/fixtures/match_pose_recorder.gd").new();service.realtime=recorder
 expect(is_equal_approx(service.pose_interval(),0.05),"connected game uses 20 Hz local send policy")
 service._last_pose_sent=Time.get_ticks_msec()-50
 expect(service.send_pose(Vector3.ONE,0,3,0,Vector3(3,0,0)) and recorder.poses.is_empty(),"connected game never duplicates poses to Supabase Broadcast")
 controllers[0].links[ids[1]].peer.close()
 expect(service.pose_interval()>=0.334,"lost RTC link immediately restores reserved fallback rate")
 service._last_pose_sent=Time.get_ticks_msec()-334;service._last_broadcast_pose=Time.get_ticks_msec()-334
 expect(service.send_pose(Vector3.ONE,0,0,0) and recorder.poses.size()==1,"lost RTC link sends bounded Supabase fallback")
 expect(not service.send_pose(Vector3.ZERO,0,0,0),"fallback cannot transmit at 20 Hz")
 service.room.pose_interval=2.0
 service._last_pose_sent=Time.get_ticks_msec()-334;service._last_broadcast_pose=Time.get_ticks_msec()-334
 expect(is_equal_approx(service.pose_interval(),2.0) and not service.send_pose(Vector3.ZERO,0,0,0),"expanded rooms obey two-second reserved fallback")
 service._last_pose_sent=Time.get_ticks_msec()-2000;service._last_broadcast_pose=Time.get_ticks_msec()-2000
 expect(service.send_pose(Vector3.ZERO,0,0,0),"expanded fallback still sends after its reserved interval")
 expect(RTC.valid_ice({"iceServers":[{"urls":["turn:turn.cloudflare.com:3478"],"username":"temp","credential":"temp"}],"expiresIn":3300}),"temporary TURN config validates")
 expect(not RTC.valid_ice({"iceServers":[{"urls":["https://invalid"]}],"expiresIn":3300}),"non-ICE URL rejected")
 expect(not RTC.valid_ice({"iceServers":[],"expiresIn":3300}),"empty TURN config rejected")
 expect(not RTC.valid_ice({"iceServers":[{"urls":["stun:test"]}],"expiresIn":INF}),"nonfinite credential expiry rejected")
 var mixed: Array=[{"urls":["stun:stun.cloudflare.com:3478","turn:turn.cloudflare.com:3478?transport=udp","turn:turn.cloudflare.com:3478?transport=tcp","turns:turn.cloudflare.com:443?transport=tcp"]}]
 var link_script=load("res://features/competition/webrtc_pose_link.gd")
 expect(link_script.ice_for_platform(mixed,false)[0].urls.size()==2,"native uses supported STUN/TURN UDP transports")
 expect(link_script.ice_for_platform(mixed,true)[0].urls.size()==4,"web retains TURN TCP and TLS fallback")
 var before_session: String=controllers[0]._session
 controllers[0]._restart_session()
 expect(controllers[0]._session!=before_session and controllers[0].links.is_empty(),"RTC reconnect replaces session and clears old links")
 for i in 3: controllers[0]._restart_session()
 expect(controllers[0]._blocked_round==room.round_id,"reconnect attempts are bounded per round")
 service.rtc=original;service.room.clear()
 for c in controllers:c.shutdown();c.queue_free()
 for stub in stubs:stub.free()
 await process_frame
 print("MATCH WEBRTC RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
