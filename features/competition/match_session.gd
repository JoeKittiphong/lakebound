extends Node3D
const REMOTE = preload("res://features/competition/remote_angler.tscn")
var game: Node3D
var service: Node
var peers := {}
var _send_clock := 0.0
var _last_phase := ""
var _round_seed := -1
var _round_id := ""
var _landed := {}
var _last_pose_position := Vector3.INF
var _last_pose_yaw := 0.0
var _last_pose_state := -1
var _last_pose_speed := -1.0
var _idle_clock := 0.0
var _fish_claim := {}
var _renew_clock := 0.0
var active := false
@export var standard_tuning: FishingTuning = preload("res://features/competition/match_tuning.tres")

func setup(value: Node3D) -> void:
 game=value
 service=get_node_or_null("/root/Competition")
 active=service!=null and not service.room.is_empty() and service.room.map==game.map_id
 set_process(active)
 if not active: return
 game.hud.set_competition_mode(true)
 game.fishing.casting_enabled=false
 game.fishing.set_physics_process(false)
 game.pond.set_physics_process(false)
 game.player.input_enabled=false
 game.fishing.tuning=standard_tuning.duplicate()
 game.fishing.session_only_catches=true
 game.fishing.bind_profile(AnglerSave)
 game.hud.bind_economy(AnglerSave,game.fishing,game.pond,game.get_node("CommerceGateway"))
 game.hud.get_node("SafeArea/BagDock").session_fish=true
 game.fishing.bite_authorizer=_authorize_bite
 game.hud.get_node("SafeArea/TopBar/Actions/Wallet").hide()
 if game.vessel!=null:
  game.vessel.hide()
  game.vessel.process_mode=Node.PROCESS_MODE_DISABLED
  game.vessel.collision_layer=0
  game.vessel.collision_mask=0
  game.vessel=null
 service.pose_received.connect(_pose)
 service.changed.connect(_changed)
 service.failed.connect(func(reason: String):
  if not _fish_claim.is_empty() and reason in ["fish_claim_expired","fish_already_caught"]:
   game.fishing.lose("สิทธิ์ปลาหมดแล้ว · เหวี่ยงเบ็ดใหม่")
   _fish_claim.clear())
 _reset_round()
 _changed()
 _process(0.0)

func _reset_round() -> void:
 _last_pose_position=Vector3.INF
 _last_pose_speed=-1.0
 _round_seed=int(service.room.seed)
 _round_id=str(service.room.round_id)
 game.fishing.cancel()
 game.pond.clock=0
 game.pond.shared_population_seed=_round_seed
 game.pond.reset_population(_round_seed)
 # Identity is shared; each angler's movement/bite RNG must not replay in lockstep.
 game.pond.rng.seed=(_round_id+":"+service._identity).hash()
 _fish_claim.clear()
 _landed.clear()
 game.hud.get_node("SafeArea/BagDock").clear_fish()

func _authorize_bite(fish: FishState) -> bool:
 var round_id := _round_id
 var generation: int=game.fishing._bite_generation
 var claim: Dictionary=await service.reserve_fish(fish.id,str(fish.species.id),maxi(1,roundi(fish.weight*1000)))
 if claim.is_empty():
  fish.available_for_bait=false
  return false
 if not is_instance_valid(game) or round_id!=_round_id or generation!=game.fishing._bite_generation or game.fishing.state!=FishingController.State.WAITING:
  service.release_fish(claim)
  return false
 _fish_claim=claim
 _renew_clock=0
 fish.weight=float(claim.grams)/1000.0
 return true

func _changed() -> void:
 if service.room.is_empty(): return
 if str(service.room.round_id)!=_round_id: _reset_round()
 var consumed := {}
 var population_changed := false
 for fish_id in service.room.get("consumed_fish",[]): consumed[int(fish_id)]=true
 for fish in game.pond.fish.duplicate():
  if consumed.has(fish.id) and fish!=game.fishing.active_fish:
   game.pond.fish.erase(fish)
   if game.pond.reserved_fish==fish: game.pond.reserved_fish=null
   population_changed=true
  else:
   var owner: Dictionary=service.fish_claim(fish.id)
   fish.available_for_bait=owner.is_empty() or owner.player_id==service._identity
 # Reconnects and restocks advance through the same global IDs, skipping every
 # consumed fish. Never use a per-client random restock identity in a match.
 while game.pond.fish.size()<game.pond.population_limit and game.pond.next_id<=100000:
  var fish: FishState=game.pond._spawn((game.pond.next_id-1)%game.pond.species.size())
  population_changed=true
  if consumed.has(fish.id): game.pond.fish.erase(fish)
 if population_changed: game.pond.population_changed.emit()
 if not _fish_claim.is_empty():
  var renewed: Dictionary=service.fish_claim(int(_fish_claim.fish_id))
  if renewed.get("claim_id","")==_fish_claim.claim_id: _fish_claim=renewed
 if service.phase()=="loading" and not service.member(service._identity).get("loaded",false): service.action("loaded")
 for id in peers.keys():
  if service.member(id).is_empty() or service.member(id).get("departed",false):
   peers[id].queue_free()
   peers.erase(id)

func _process(delta: float) -> void:
 if service.room.is_empty(): return
 var phase: String=service.phase()
 var running := phase=="running"
 var blocked: bool=game._modal_active or game.get_node("MatchHUD/MatchPanel").visible
 if phase!=_last_phase:
  if not running and phase not in ["loading","countdown"]: game.fishing.cancel()
  _last_phase=phase
 game.player.input_enabled=running and not blocked and game.fishing.state!=FishingController.State.RESULT
 game.camera_rig.enabled=running and not blocked and game.fishing.state!=FishingController.State.RESULT
 game.fishing.set_physics_process(running and not blocked)
 game.fishing.casting_enabled=running and not blocked
 game.pond.set_physics_process(running)
 if not _fish_claim.is_empty():
  if game.fishing.state in [FishingController.State.BITE,FishingController.State.FIGHT]:
   if service.server_now()>=float(_fish_claim.expires_at) or Time.get_ticks_msec()-service._clock_ticks>=45000:
    game.fishing.lose("ยืนยันสิทธิ์ปลาไม่ได้ · ปล่อยปลาแล้วลองใหม่")
   else:
    _renew_clock+=delta
    if _renew_clock>=10.0:
     _renew_clock=0
     service.action("renew_fish",{"fish_id":int(_fish_claim.fish_id),"claim_id":str(_fish_claim.claim_id),"round_id":_round_id})
  elif game.fishing.state!=FishingController.State.RESULT:
   service.release_fish(_fish_claim)
   _fish_claim.clear()
 _send_clock+=delta
 _idle_clock+=delta
 if running and _send_clock>=service.pose_interval() and _pose_changed(game.player.global_position,game.player.visual.global_rotation.y,game.player.actual_ground_speed,game.fishing.state):
  if service.send_pose(game.player.global_position,game.player.visual.global_rotation.y,game.player.actual_ground_speed,game.fishing.state,game.player.get_real_velocity()):
   _send_clock=0
   _idle_clock=0
   _last_pose_position=game.player.global_position
   _last_pose_yaw=game.player.visual.global_rotation.y
   _last_pose_state=game.fishing.state
   _last_pose_speed=game.player.actual_ground_speed

func _pose_changed(position: Vector3, yaw: float, speed: float, fishing_state: int) -> bool:
 return position.distance_to(_last_pose_position)>0.06 or absf(angle_difference(_last_pose_yaw,yaw))>0.04 or fishing_state!=_last_pose_state or absf(speed-_last_pose_speed)>0.04 or speed>0.04 or _idle_clock>=6.0

func landed(fish: FishState) -> void:
 if _landed.has(fish.persistent_key): return
 _landed[fish.persistent_key]=true
 # Initial fish IDs are deterministic for the shared seed, including after a
 # reconnect. Re-catching the same initial fish retries the same score event.
 var id := (str(service.room.round_id)+":"+str(fish.id)).md5_text()
 var queued: bool=service.submit_catch(str(fish.species.id),maxi(1,roundi(fish.weight*1000)),id,_fish_claim)
 _fish_claim.clear()
 game.fishing.feedback="ส่งผลแข่งขันแล้ว · รอคะแนนยืนยันในกระดาน" if queued else "ยังไม่เชื่อมต่อหรือหมดเวลา · ไม่นับปลาตัวนี้"
 if queued and not MatchRules.counts_species(service.room,str(fish.species.id)): game.fishing.feedback="ปลาตัวนี้ไม่ใช่ชนิดที่กำหนด · นำออกจากสนามแต่ไม่นับคะแนน"
 game.hud.get_node("SafeArea/BagDock").add_fish({"species":str(fish.species.id),"name":fish.species.display_name,"weight":fish.weight})
 game.fishing.resolve_catch(true)

func can_cast() -> bool:
 return active and service.phase()=="running" and not game._modal_active and not game.get_node("MatchHUD/MatchPanel").visible

func select_bait(bait: String) -> void:
 game.fishing.session_bait=TackleCatalog.item("minnow" if bait=="lure" else bait)

func _pose(pose: Dictionary) -> void:
 if not peers.has(pose.id):
  var peer := REMOTE.instantiate()
  add_child(peer)
  peers[pose.id]=peer
 peers[pose.id].interpolation_delay=0.08 if pose.get("_webrtc",false) else 0.18
 peers[pose.id].prediction_limit=0.2 if pose.get("_webrtc",false) else 0.45
 peers[pose.id].apply_pose(pose,str(service.member(pose.id).get("name","นักตกปลา")))
