extends SceneTree
const Progress = preload("res://features/collection/collection_progress.gd")
var checks:=0
var failures:=0
var output:=OS.get_environment("LAKEBOUND_QA_DIR")
func _initialize() -> void: call_deferred("run")
func expect(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL: "+message)
 else:print("PASS: "+message)
func frames()->void:
 for frame in 6:await process_frame
func capture(name:String)->void:
 if output.is_empty() or DisplayServer.get_name()=="headless":return
 await frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run()->void:
 var collection:Node=root.get_node("FishCollection")
 collection.recording_enabled=false
 collection.save_error=""
 collection.records={"tilapia":{"count":5,"best":3.5}}
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.data.history.map_bests={"lotus_marsh:tilapia":{"map":"lotus_marsh","species":"tilapia","weight":1.2}}
 profile.data.journal=[{"map":"lotus_marsh","species":"tilapia","weight":2.0}]
 for region in RegionCatalog.MAPS:
  var scene:PackedScene=load(region.scene)
  var state:=scene.get_state()
  var actual:=[]
  for node in state.get_node_count():
   if state.get_node_name(node)!=&"PondEcosystem":continue
   for property in state.get_node_property_count(node):
    if state.get_node_property_name(node,property)==&"species":
     for species in state.get_node_property_value(node,property):
      if String(species.id) not in actual:actual.append(String(species.id))
  var indexed:Array=Progress.species_for(region.id).map(func(species:Resource):return String(species.id))
  actual.sort();indexed.sort()
  expect(actual==indexed,"collection uses exact pond membership: "+region.id)
 expect(Progress.map_records(profile.data,"lotus_marsh").tilapia.best==2.0,"legacy journal and lifetime map best combine without duplicate discovery")
 profile.data.journal=[]
 expect(Progress.map_records(profile.data,"lotus_marsh").has("tilapia"),"journal compaction does not forget a map discovery")
 expect(not Progress.map_records(profile.data,"river").has("tilapia"),"a catch on one map never unlocks the same species on another")
 var panel:Control=load("res://features/collection/collection_panel.tscn").instantiate()
 root.size=Vector2i(1280,720)
 root.add_child(panel)
 panel.open()
 await frames()
 for frame in 240:
  if panel.phase == "ready": break
  await process_frame
 await frames()
 var tabs:VBoxContainer=panel.get_node("Card/Content/MapTabs")
 var rows:GridContainer=panel.get_node("Card/Content/Scroll/Rows")
 expect(tabs.get_child_count()==7 and panel.filtered_species.size()==collection.SPECIES.size() and rows.get_child_count()==15,"all-species tab remains available alongside six map tabs")
 var tab_point: Vector2 = tabs.get_child(2).get_global_rect().get_center()
 for pressed in [true,false]:
  var touch:=InputEventScreenTouch.new()
  touch.index=3
  touch.position=tab_point
  touch.pressed=pressed
  root.push_input(touch,true)
  await process_frame
 expect(panel.selected_map=="lotus_marsh","touching a map tab changes the real collection filter")
 panel.select_map(2)
 await frames()
 expect(panel.selected_map=="lotus_marsh" and rows.get_child_count()==14,"lotus tab contains only its fourteen species")
 expect("1 / 14" in panel.get_node("Card/Content/Header/Summary").text and "13" in panel.get_node("Card/Content/Header/Summary").text,"map summary shows discovered and remaining species counts")
 var tilapia_row:Control
 for row in rows.get_children():
  if row.species_id=="tilapia":tilapia_row=row
 expect(tilapia_row!=null and tilapia_row.revealed,"the map's recorded species is revealed")
 expect("1.20" in tilapia_row.get_node("Content/Stats").text and not "5 ตัว" in tilapia_row.get_node("Content/Stats").text,"map card uses map weight and does not mislabel a global catch count")
 var filter:CheckButton=panel.get_node("Card/Content/Filters/OnlyMissing")
 filter.button_pressed=true
 await frames()
 expect(rows.get_child_count()==13,"missing-only filter removes discovered fish")
 for row in rows.get_children():
  expect(not row.get_node("Content/Name").visible and row.get_node("Content/Preview/Question").visible,"undiscovered fish keep their silhouette and question mark")
 filter.button_pressed=false
 panel.select_map(1)
 await frames()
 expect(("0 / %d" % RegionCatalog.find("river").fish_count) in panel.get_node("Card/Content/Header/Summary").text,"river stays undiscovered despite the global tilapia discovery")
 for row in rows.get_children():
  if row.species_id=="tilapia":expect(not row.get_node("Content/Name").visible,"tilapia remains hidden on a map where it was never caught")
 for resolution in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1024,768)]:
  root.size=resolution
  for index in range(1,7):
   panel.select_map(index)
   await frames()
   var card:Control=panel.get_node("Card")
   expect(card.get_global_rect().encloses(tabs.get_global_rect()),"scrollable map tabs fit %s map %d" % [resolution,index])
   expect(panel.get_node("Card/Content/Scroll").size.y>180,"fish grid keeps usable height at %s" % resolution)
   if index==2 or index==6:await capture("collection_%dx%d_map%d" % [resolution.x,resolution.y,index])
 panel.select_map(2)
 for species in Progress.species_for("lotus_marsh"):
  profile.data.history.map_bests["lotus_marsh:"+String(species.id)]={"map":"lotus_marsh","species":String(species.id),"weight":1.0}
 filter.button_pressed=true
 await frames()
 expect(rows.get_child_count()==0 and panel.get_node("Card/Content/Filters/Empty").visible,"completed map displays a clear empty state with missing-only enabled")
 panel.close()
 await panel.closed
 panel.open()
 await frames()
 for frame in 240:
  if panel.phase == "ready": break
  await process_frame
 expect(panel.selected_map=="lotus_marsh" and filter.button_pressed,"reopening retains selected map and filter")
 panel.queue_free()
 await frames()
 print("COLLECTION TABS RESULT: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
