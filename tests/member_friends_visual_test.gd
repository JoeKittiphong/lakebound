extends "res://tests/competition_test.gd"
func run() -> void:
 var service: Node=root.get_node("Competition")
 service.enabled=false;service.edge.enabled=true;service.edge.connected=true
 var room:=fixture()
 room.members[1].name="เพื่อนเดิม"
 for i in 3:
  var member: Dictionary=room.members[1].duplicate(true);member.id=["b","c","d"][i].repeat(32);member.name=["รอการตอบรับ","ส่งคำขอถึงคุณ","ผู้เล่นทั่วไป"][i];room.members.append(member)
 service.room=room
 service.edge.social={"self":{"code":"1234ABCD"},"friends":[{"id":"a".repeat(32),"name":"เพื่อนเดิม","code":"AAAAAAAA","status":"in_room"}],"outgoing":[{"id":"b".repeat(32),"name":"รอการตอบรับ","code":"BBBBBBBB","status":"unknown"}],"incoming":[{"id":"c".repeat(32),"name":"ส่งคำขอถึงคุณ","code":"CCCCCCCC","status":"unknown"}],"invites":[]}
 root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
 var panel=load("res://features/competition/match_panel.tscn").instantiate();panel.auto_travel=false;root.add_child(panel);panel.open()
 var rows: Array=panel.get_node("%Rows").get_children()
 expect(not rows[0].get_node("Line/AddFriend").visible,"own row has no add-self button")
 expect(rows[1].get_node("Line/AddFriend").text=="เป็นเพื่อนแล้ว" and rows[1].get_node("Line/AddFriend").disabled,"existing friend is clearly marked")
 expect(rows[2].get_node("Line/AddFriend").text=="ส่งคำขอแล้ว" and rows[2].get_node("Line/AddFriend").disabled,"pending outgoing request prevents duplicate sends")
 expect(rows[3].get_node("Line/AddFriend").text=="รับเป็นเพื่อน" and not rows[3].get_node("Line/AddFriend").disabled,"incoming request can be accepted in the room")
 expect(rows[4].get_node("Line/AddFriend").text=="เพิ่มเพื่อน" and not rows[4].get_node("Line/AddFriend").disabled,"unrelated room member has an add-friend button")
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/qa-two-player/member-friends-panel.png")
 service.room.clear();panel.render()
 expect(not panel.get_node("%QuickJoin").disabled,"quick join does not require a friendship")
 print("MEMBER FRIENDS UI RESULT: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
