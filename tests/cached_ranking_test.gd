extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
 if not ok: failures+=1
 print("PASS: " if ok else "FAIL: ",message)
func run() -> void:
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.data.identity.name="ทดสอบแคชอันดับ"
 var endpoint: String="https://script.google.com/macros/s/QA_CACHE_RENDER/exec"
 var writer:=SheetsRankingSync.new()
 writer.save_path="user://cache-render-ack.cfg"
 writer.cache_path="user://cache-render-views.cfg"
 writer.configure(endpoint,str(profile.data.identity.id))
 writer.build(profile,"all","",100)
 var rows: Array=[]
 for i in 100:
  rows.append(["%032x"%(i+1),"นักตกปลาทดสอบ %d"%(i+1),"river","tilapia",100000-i*100])
 expect(not writer.accept({"schema":3,"version":"render-fixture-100","rows":rows}).is_empty(),"persist compact 100-row fixture locally")
 var panel: Control=load("res://features/social/social_panel.tscn").instantiate()
 root.add_child(panel)
 panel.sheets_url=endpoint
 panel.top_limit=100
 panel.get_node("%TopLimit").select(2)
 panel.sheets_sync.save_path=writer.save_path
 panel.sheets_sync.cache_path=writer.cache_path
 root.size=Vector2i(1280,720)
 var start:=Time.get_ticks_usec()
 panel.sheets_sync.configure(endpoint,str(profile.data.identity.id))
 panel.show()
 panel._show_cached()
 panel.get_node("%Status").text="อันดับที่บันทึกไว้ · แสดงจากแคชในเครื่อง (ข้อมูลทดสอบภาพ)"
 await process_frame
 await RenderingServer.frame_post_draw
 var elapsed:=float(Time.get_ticks_usec()-start)/1000.0
 expect(panel.displaying_cached and panel.get_node("%Rows").get_child_count()==100,"reopen and render 100 cached rankings without network")
 expect(panel.request.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED,"cache rendering does not perform a hidden request")
 expect(elapsed<1000.0,"first draw of cached Top100 is below one second")
 print("CACHED TOP100 FIRST DRAW: %.3f ms"%elapsed)
 var directory:=OS.get_environment("LAKEBOUND_QA_DIR")
 if not directory.is_empty(): root.get_texture().get_image().save_png(directory+"/cached-ranking-100.png")
 panel.queue_free()
 print("CACHED RANKING RESULT: %d failures"%failures)
 quit(1 if failures else 0)
