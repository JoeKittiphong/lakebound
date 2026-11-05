extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
 checks += 1
 if not ok: failures += 1
 print("PASS: " if ok else "FAIL: ",message)
func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.data.identity.name = "นักตกปลาริมน้ำ"
 for index in 15:
  profile.data.journal.append({"catch_id":"preview-%d"%index,"species":"tilapia","name":"ปลานิล","weight":float(index+1)/10.0,"map":"coral_coast" if index==0 else "river","time":1000.0+index})
 var panel: Control = load("res://features/social/social_panel.tscn").instantiate()
 panel.supabase_key = "sb_publishable_fixture"
 root.add_child(panel)
 panel.supabase_url=""
 for entry in RegionCatalog.MAPS:
  panel.open_for_map(entry.id)
  var filter: OptionButton = panel.get_node("%Filter")
  expect(panel.scope == "map" and str(filter.get_item_metadata(filter.selected)) == entry.id, "direct map ranking selects " + str(entry.id))
  panel.close()
 panel.open()
 expect(profile.data.journal.size()==10 and profile.lifetime_catches()==15,"ranking reads bounded history and lifetime total")
 expect(panel.get_node("%TopLimit").item_count==3,"Top10/50/100 controls authored")
 panel._mode_changed(1)
 expect(panel.get_node("%Filter").item_count==6,"ranking supports all six maps")
 panel.get_node("%Filter").select(5)
 panel._selection_changed()
 expect(panel.get_node("%Rows").get_child_count()==1,"coast best remains visible after dropping out of retained top ten")
 expect("0.100" in panel.get_node("%Personal").text,"personal best is scoped to selected map")
 var networkRows: Array=[]
 for i in 12:
  networkRows.append(["%032x" % (i+1),"นักตกปลา %d"%(i+1),"tilapia",3000-i*100])
 panel.get_node("%Filter").select(0)
 panel._selection_changed()
 panel.ranking_sync.configure("https://abcdefghijklmnopqrst.supabase.co/rest/v1/rpc/lakebound_rankings",str(profile.data.identity.id))
 panel.ranking_sync.build(profile,"map","river",10)
 panel._received(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"schema":3,"version":"top10","rows":networkRows.slice(0,10)}).to_utf8_buffer())
 expect(panel.online and panel.get_node("%Rows").get_child_count()==10,"online Top10 limits displayed players")
 expect(str(RegionCatalog.find("river").name) in panel.get_node("%ScopeTitle").text,"ranking heading names the selected map")
 for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540)]:
  root.size=dimensions
  for i in 6: await process_frame
  await RenderingServer.frame_post_draw
  var canvas_size := root.get_visible_rect().size
  for nodeName in ["Close","Filter","TopLimit","Refresh","Personal","HistorySummary"]:
   var control: Control=panel.get_node("%"+nodeName)
   var rect:=control.get_global_rect()
   expect(rect.position.x>=0 and rect.end.x<=canvas_size.x+1 and rect.position.y>=0 and rect.end.y<=canvas_size.y+1,"%s fits %dx%d"%[nodeName,dimensions.x,dimensions.y])
  var directory:=OS.get_environment("LAKEBOUND_QA_DIR")
  if not directory.is_empty(): root.get_texture().get_image().save_png(directory+"/ranking-maps-%dx%d.png"%[dimensions.x,dimensions.y])
 panel.top_limit=50
 panel.ranking_sync.build(profile,"map","river",50)
 panel._received(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"schema":3,"version":"top50","rows":networkRows}).to_utf8_buffer())
 expect(panel.get_node("%Rows").get_child_count()==12,"Top50 can display more than ten players")
 panel._mode_changed(1)
 panel.get_node("%Filter").select(1)
 panel._selection_changed()
 expect(panel.get_node("%Rows").get_child_count()==0 and panel.get_node("%Empty").visible,"uncaught map shows honest empty state")
 panel.queue_free()
 print("RANKING MAPS RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
