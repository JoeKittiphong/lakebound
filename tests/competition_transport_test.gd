extends "res://tests/competition_test.gd"
func run() -> void:
 root.get_node("Competition").enabled=false
 root.get_node("RankingOnline").enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.data.identity.name="นักตกปลา QA"
 var client: Node=load("res://features/competition/match_service.tscn").instantiate()
 client.set_script(load("res://tests/fixtures/match_fake_service.gd"))
 root.add_child(client)
 client.set_process(false)
 client.enabled=true
 var snap := fixture()
 var auth: Node=load("res://features/auth/account_auth.tscn").instantiate()
 auth.set_script(load("res://tests/fixtures/fake_google_auth.gd"))
 root.add_child(auth)
 auth.set_process(false)
 var session := {"access_token":"fake-jwt","refresh_token":"rotated-session","expires_in":3600,"user":{"id":"10000000-0000-4000-8000-000000000001","email":"qa@example.test","app_metadata":{"provider":"google"},"is_anonymous":false}}
 auth._accept_session(session)
 auth.account_ready=true
 auth.expires_at=0
 auth.responses=[session]
 client.account_auth=auth
 client.responses=[snap]
 client.action("create",{"map":"lotus_marsh"})
 await client._pump()
 expect(auth.calls[0].path.ends_with("grant_type=refresh_token"),"refresh Google session before RPC")
 expect(client.calls[0].authenticated and client.calls[0].body.payload.token==profile.data.identity.token,"match RPC carries both Google JWT and profile proof")
 expect(client.room.id==snap.id and client.connected,"authoritative snapshot establishes room")
 client.responses=[{"error":"network_error"}]
 client.action("state")
 await client._pump()
 expect(not client.connected and client._queue.size()==1,"network error retains operation for retry")
 client.responses=[snap]
 await client._pump()
 expect(client.connected and client._queue.is_empty(),"retry restores authoritative state")
 client.responses=[{"error":"jwt_expired"}]
 client.action("state")
 await client._pump()
 expect(client._expires==0 and client._queue.size()==1,"401 preserves operation and requests token refresh")
 session.access_token="new-jwt"
 auth.responses=[session]
 client.responses=[snap]
 await client._pump()
 expect(client.connected and client._access=="new-jwt","refreshed token resumes operation")
 client.responses=[snap]
 client.action("state")
 client._pump()
 client.forget_room()
 await process_frame
 await process_frame
 expect(client.room.is_empty(),"in-flight old response cannot resurrect abandoned room")
 client.room=snap
 client.responses=[{"error":"not_a_member"}]
 client.action("leave")
 await client._pump()
 expect(client.room.is_empty(),"lost leave acknowledgment recovers on retry")
 client.responses=[{"error":"rate_limited"}]
 client.action("quick_join")
 await client._pump()
 expect(client._queue.size()==1 and client._retry_at>Time.get_ticks_msec()/1000.0+1,"rate limit retains intent with delayed backoff")
 client._queue.clear()
 auth.expires_at=0
 auth.responses=[{"error":"invalid_refresh_token"}]
 expect(not await client._authenticate(),"revoked Google session blocks competition")
 expect(auth.calls[-1].path.ends_with("grant_type=refresh_token"),"no anonymous signup fallback after Google logout")
 client.queue_free()
 auth.queue_free()
 await process_frame
 print("COMPETITION TRANSPORT RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
