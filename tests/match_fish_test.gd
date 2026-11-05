extends "res://tests/competition_test.gd"
var allow_bite := false
func gate(_fish: RefCounted) -> bool:
 await process_frame
 return allow_bite
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false
 service.set_process(false)
 root.get_node("RankingOnline").enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.data.identity.name="นักตกปลา QA"
 service._identity=profile.data.identity.id
 service.room=fixture();service.room.phase="running";service.room.starts_at=999;service.room.ends_at=1600
 service._clock_server=1000;service._clock_ticks=Time.get_ticks_msec();service.connected=true
 var game: Node3D=load("res://features/regions/lotus_marsh.tscn").instantiate()
 root.add_child(game);current_scene=game
 var session: Node=game.get_node("MatchSession")
 session.set_process(false);game.pond.set_physics_process(false);game.fishing.set_physics_process(false)
 game.get_node("FishingEffects").audio_enabled=false
 var fish: FishState=game.pond.fish[0]
 game.fishing.bite_authorizer=gate
 game.fishing._change_state(FishingController.State.WAITING)
 game.pond.reserved_fish=fish
 game.fishing._on_fish_biting(fish)
 expect(game.fishing.state==FishingController.State.WAITING and game.fishing.active_fish==null,"bite and haptics wait for server authorization")
 for i in 3: await process_frame
 expect(game.fishing.state==FishingController.State.WAITING and game.pond.reserved_fish==null,"denied ownership keeps bait waiting for another fish")
 allow_bite=true
 game.fishing._on_fish_biting(fish)
 for i in 3: await process_frame
 expect(game.fishing.state==FishingController.State.BITE and game.fishing.active_fish==fish,"authorized bite opens full strike window")
 game.fishing.cancel()
 game.fishing._change_state(FishingController.State.WAITING)
 game.fishing._on_fish_biting(fish)
 game.fishing.cancel()
 for i in 3: await process_frame
 expect(game.fishing.state==FishingController.State.READY and game.fishing.active_fish==null,"cancelled cast cannot receive delayed bite")
 var consumed_id: int=game.pond.fish[0].id
 var busy: FishState=game.pond.fish[1]
 var nonce := "10000000-0000-4000-8000-000000000001"
 service.room.consumed_fish=[consumed_id]
 service.room.fish_claims=[[busy.id,"a".repeat(32),nonce,1090,str(busy.species.id),roundi(busy.weight*1000)]]
 session._changed()
 expect(not game.pond.fish.any(func(f): return f.id==consumed_id),"remote caught fish is removed from local population")
 expect(not busy.available_for_bait,"other angler's claimed fish cannot approach local bait")
 expect(game.pond.fish.size()==game.pond.population_limit,"shared population restocks with next global IDs")
 var latest: FishState=game.pond.fish[-1]
 var latest_id: int=latest.id
 var latest_weight: float=latest.weight
 session._reset_round();session._changed()
 var restored: FishState=null
 for f in game.pond.fish:
  if f.id==latest_id: restored=f
 expect(restored!=null and is_equal_approx(restored.weight,latest_weight),"reconnect skips consumed IDs and recreates identical replacement fish")
 service.room.fish_claims=[];session._changed()
 expect(game.pond.fish.all(func(f): return f.available_for_bait),"released or expired remote reservations become available again")
 var one := PondEcosystem.new();var two := PondEcosystem.new()
 for pond in [one,two]: pond.shared_population_seed=512;pond.reset_population(512)
 for i in 100: one.rng.randf()
 var first: FishState=one._spawn(0);var second: FishState=two._spawn(9)
 expect(first.id==second.id and first.species.id==second.species.id and first.weight==second.weight,"fish identity and weight are independent of each player's simulation RNG")
 one.free();two.free()
 expect(not service.submit_catch("tilapia",1000,"f".repeat(32)),"local score API refuses unclaimed fish")
 var wire:=fixture();wire.fish_claims=[[7,service._identity,nonce,1090,"tilapia",1000]];wire.consumed_fish=[1,2]
 expect(SERVICE.valid_snapshot(JSON.parse_string(JSON.stringify(wire))),"compact ownership snapshot validates after real JSON decoding")
 wire.fish_claims.append(wire.fish_claims[0])
 expect(not SERVICE.valid_snapshot(wire),"duplicate fish ownership in snapshot rejected")
 var client: Node=load("res://features/competition/match_service.tscn").instantiate()
 client.set_script(load("res://tests/fixtures/match_fake_service.gd"));root.add_child(client)
 var auth: Node=load("res://features/auth/account_auth.tscn").instantiate()
 auth.set_script(load("res://tests/fixtures/fake_google_auth.gd"));root.add_child(auth);auth.set_process(false)
 auth.access_token="fake-jwt";auth.user_id="10000000-0000-4000-8000-000000000001";auth.account_ready=true;auth.expires_at=Time.get_unix_time_from_system()+3600
 client.account_auth=auth;client.enabled=true;client._last_rt_attempt=1e15
 wire=fixture();wire.phase="running";wire.starts_at=999;wire.ends_at=1600
 wire.fish_claims=[[7,service._identity,nonce,1090,"tilapia",1000]];wire.consumed_fish=[]
 client.room=wire;client.connected=true;client._clock_server=1000;client._clock_ticks=Time.get_ticks_msec();client.responses=[wire]
 var claim: Dictionary=await client.reserve_fish(7,"tilapia",1000)
 expect(claim.get("claim_id","")==nonce and client.calls[0].body.payload.op=="claim_fish","bite reservation travels through async HTTP queue and returns owner nonce")
 client.responses=[{"error":"fish_busy"}]
 expect((await client.reserve_fish(8,"tilapia",1000)).is_empty(),"racing bite denied by server never unlocks hook")
 client._queue.clear();client._complete_claim({"op":"claim_fish","fish_id":7,"_claim_ticket":"abandoned"},wire)
 expect(client._queue.size()==1 and client._queue[0].op=="release_fish","late successful claim from abandoned cast is released")
 client.queue_free();auth.queue_free();service.room.clear();game.queue_free()
 await process_frame
 print("MATCH FISH RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
