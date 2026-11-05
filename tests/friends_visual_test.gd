extends "res://tests/competition_test.gd"
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false;service.edge.connected=true;service.room=fixture();service.edge.social={"self":{"code":"A1B2C3D4"},"friends":[{"id":"2".repeat(32),"name":"เพื่อนตกปลา","status":"online"},{"id":"3".repeat(32),"name":"นักตกปลาริมน้ำ","status":"playing"},{"id":"4".repeat(32),"name":"เพื่อนออฟไลน์","status":"offline"}],"incoming":[{"id":"5".repeat(32),"name":"ผู้เล่นใหม่"}],"outgoing":[],"invites":[{"id":"invite-test","name":"เพื่อนสนิท","code":"01234","expires_at":Time.get_unix_time_from_system()+60}]}
 root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
 var panel=load("res://features/competition/friends_panel.tscn").instantiate();root.add_child(panel);panel.show();panel.render()
 expect(panel.get_node("%Friends").get_child_count()==3,"authored friends panel renders online, playing and offline friends")
 expect(panel.get_node("%Requests").get_child_count()==1,"friend request has explicit accept and decline controls")
 expect(panel.get_node("%Invites").get_child_count()==1,"room invitation renders without joining automatically")
 expect(panel.get_node("%Friends").get_child(0).get_node("Primary").disabled==false,"online friend can be invited from lobby")
 expect(panel.get_node("%Friends").get_child(1).get_node("Primary").disabled,"busy friend cannot be invited")
 expect(panel.get_node("%Invites").get_child(0).get_node("Primary").disabled,"must leave current room before accepting another invitation")
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/qa-two-player/friends-panel.png")
 print("FRIENDS UI RESULT: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
