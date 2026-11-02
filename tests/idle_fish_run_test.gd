extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func expect(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func run()->void:
 var tuning:=FishingTuning.new()
 var controller:=FishingController.new()
 var pond:=PondEcosystem.new()
 var player:=Node3D.new();root.add_child(player)
 controller.player=player;controller.ecosystem=pond
 var hooked:=FishState.new();hooked.species=load("res://data/fish/tilapia.tres");hooked.weight=2;hooked.position=Vector3(0,1,-15)
 controller.state=FishingController.State.WAITING
 controller._on_fish_biting(hooked)
 expect(controller.state==FishingController.State.BITE and is_equal_approx(controller.tension,.13),"bite controller immediately uses grey")
 expect(controller.strike() and controller.state==FishingController.State.FIGHT and is_equal_approx(controller.tension,.13),"strike keeps grey and requires player input")
 controller.free();pond.free();player.queue_free()
 for species in ["tilapia","giant_catfish"]:
  for fps in [30,60,120]:
   var fish:=FishState.new();fish.id=5;fish.weight=2 if species=="tilapia" else 25
   fish.species=load("res://data/fish/"+species+".tres");fish.position=Vector3(0,1,-15)
   var sim:=FightSimulation.new();sim.begin(fish,tuning);sim.line_length=15.3
   expect(sim.tension>=.12 and sim.tension<.15,"hook starts in grey")
   var start_health:=sim.health
   for i in fps*8:sim.advance(1.0/fps,Vector3.ZERO,fish,Vector2.ZERO,tuning)
   expect(sim.tension>=.12 and sim.tension<.15,"idle remains grey before spool limit")
   expect(Vector2(fish.position.x,fish.position.z).length()>20,"idle fish runs outward")
   expect(sim.line_length>20 and sim.line_length<=tuning.spool_capacity,"idle fish takes line")
   expect(is_equal_approx(sim.health,start_health),"idle never damages fish")
   var distance:=Vector2(fish.position.x,fish.position.z).length()
   for i in fps:sim.advance(1.0/fps,Vector3.ZERO,fish,Vector2(0,.6),tuning)
   expect(sim.tension>.15,"active pull raises tension")
   # Releasing after a pull must stop automatic retrieval.
   for i in fps*2:sim.advance(1.0/fps,Vector3.ZERO,fish,Vector2.ZERO,tuning)
   expect(sim.tension<.15,"release returns to grey")
   expect(Vector2(fish.position.x,fish.position.z).length()>distance,"released fish runs again")
 print("IDLE FISH RUN: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
