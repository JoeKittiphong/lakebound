extends SceneTree
## Interactive shortcut to the authored cave; normal region entry remains the southwest jetty.
func _initialize() -> void:call_deferred("open_cave")
func open_cave() -> void:
 var game: Node3D=load("res://features/regions/grand_river.tscn").instantiate()
 root.add_child(game);current_scene=game
 for i in 90:await physics_frame
 game.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip()
 var boat: FishingBoat=game.get_node("FishingBoat")
 var player: AnglerPlayer=game.get_node("Player")
 boat.global_position=game.get_node("World/CliffFishingCave/CaveMarkers/BoatApproach").global_position
 boat.rotation.y=0
 player.global_position=boat.global_position+Vector3(3,.2,0);player.velocity=Vector3.ZERO
 boat.board(player)
 game.get_node("CameraRig").global_position=player.global_position
 game.get_node("CameraRig").rotation.y=0

 print("CAVE_PREVIEW_READY fish=",game.get_node("PondEcosystem").fish.size()," species=",game.get_node("PondEcosystem").species.size())
