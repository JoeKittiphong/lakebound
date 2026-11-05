extends "res://tests/competition_test.gd"
func run() -> void:
 root.get_node("Competition").enabled=false
 root.get_node("RankingOnline").enabled=false
 var auth: Node=load("res://features/auth/account_auth.tscn").instantiate()
 auth.set_script(load("res://tests/fixtures/fake_google_auth.gd"))
 root.add_child(auth)
 auth.set_process(false)
 var verifier := "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
 expect(OAuthPKCE.challenge(verifier)=="E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM","PKCE S256 matches RFC 7636 test vector")
 var generated := OAuthPKCE.verifier()
 expect(generated.length()==43 and not generated.contains("="),"random verifier has valid entropy/encoding")
 var redirect := "com.zylaah.lakebound://auth/callback"
 var web_redirect := "https://lakebound-zylaah.netlify.app/"
 expect(OAuthPKCE.callback_code(web_redirect+"?code=valid-code",web_redirect)=="valid-code","web callback accepts exact production route")
 for url in [web_redirect+"?code=valid-code&code=duplicate",web_redirect+"?error=access_denied&code=valid-code",web_redirect+"?code=valid-code#access_token=secret","https://lakebound-zylaah.netlify.app.evil/?code=valid-code"]:
  expect(OAuthPKCE.callback_code(url,web_redirect).is_empty(),"web callback rejects duplicate, cancelled, implicit or wrong-origin response")
 expect(OAuthPKCE.callback_code(redirect+"?code=valid-code",redirect)=="valid-code","callback accepts code at exact route")
 for url in ["https://evil.test/?code=valid-code",redirect+"/other?code=valid-code",redirect+"?code=valid-code&code=duplicate",redirect+"?error=denied&code=valid-code",redirect+"#access_token=secret"]:
  expect(OAuthPKCE.callback_code(url,redirect).is_empty(),"untrusted/duplicate/implicit callback rejected")
 var uid := "10000000-0000-4000-8000-"+Crypto.new().generate_random_bytes(6).hex_encode()
 var response := {"access_token":"test-jwt","refresh_token":"test-refresh","expires_in":3600,"user":{"id":uid,"email":"qa@example.test","app_metadata":{"provider":"google"},"is_anonymous":false}}
 var wrong := response.duplicate(true)
 wrong.user.app_metadata.provider="email"
 expect(not auth._accept_session(wrong),"non-Google session rejected")
 wrong=response.duplicate(true);wrong.user.is_anonymous=true
 expect(not auth._accept_session(wrong),"anonymous session rejected")
 expect(auth._accept_session(response) and not auth.signed_in(),"session alone cannot unlock matches before account profile")
 var identity := {"id":Crypto.new().generate_random_bytes(16).hex_encode(),"token":Crypto.new().generate_random_bytes(32).hex_encode(),"name":"นักตกปลาใหม่"}
 # A returning Google account can still have an old installation's save.
 # The one-time reset must ignore it, then retain new progress on later logins.
 var legacy_folder := "user://accounts_v1/"+uid
 DirAccess.make_dir_recursive_absolute(legacy_folder)
 var legacy := ProfileStore.defaults()
 legacy.identity=identity.duplicate(true)
 legacy.coins=987654
 legacy.diamonds=4321
 legacy.stock.worm=999
 expect(ProfileStore.save_profile(legacy_folder+"/profile.cfg",legacy)==OK,"legacy account fixture saved")
 auth.responses=[{"identity":identity}]
 await auth._load_account(auth._generation)
 var profile: AnglerProfile=root.get_node("AnglerSave")
 expect(auth.signed_in() and profile.data.identity.id==identity.id,"account RPC binds Google identity to game profile")
 expect(profile.data.coins==350 and profile.data.journal.is_empty(),"new Google account starts with fresh progress")
 expect(profile.data.diamonds==0 and profile.data.stock.worm==20,"reset ignores legacy wallet and inventory for returning Google account")
 var generated_identity := identity.duplicate(true)
 generated_identity.name="นักตกปลา "+str(identity.id).left(6)
 auth.responses=[{"identity":generated_identity}]
 await auth._load_account(auth._generation)
 expect(auth.needs_name and not auth.signed_in(),"generated name requires player choice before online play")
 var calls_before: int=auth.calls.size()
 await auth.save_player_name("<bad>")
 expect(auth.calls.size()==calls_before and auth.needs_name,"invalid name never reaches server or unlocks play")
 auth.responses=[{"error":"network_error"}]
 await auth.save_player_name("ชื่อของฉัน")
 expect(auth.needs_name and not auth.busy and not auth.signed_in(),"failed name save stays retryable and locked")
 var chosen_identity := identity.duplicate(true)
 chosen_identity.name="ชื่อของฉัน"
 auth.responses=[{"ok":true},{"identity":chosen_identity}]
 await auth.save_player_name("  ชื่อของฉัน  ")
 expect(auth.signed_in() and not auth.needs_name and profile.data.identity.name=="ชื่อของฉัน","server-confirmed custom name unlocks account")
 expect(auth.calls[-2].authenticated and auth.calls[-2].body.payload.player_name=="ชื่อของฉัน","name save uses authenticated RPC and trims whitespace")
 auth.responses=[{"identity":chosen_identity}]
 await auth._load_account(auth._generation)
 expect(not auth.needs_name and auth.signed_in(),"returning custom name skips name setup")
 identity=chosen_identity
 profile.data.coins=437
 ProfileStore.save_profile(profile.save_path,profile.data)
 var first_path: String=profile.save_path
 expect(auth._switch_profile("offline",{}) and profile.save_path!=first_path,"offline profile isolated from Google account")
 expect(auth._switch_profile(uid,identity) and profile.data.coins==437,"returning account reopens its own progress")
 auth.refresh_token="existing"
 auth.expires_at=0
 auth.responses=[response]
 expect(await auth.ensure_session(),"saved Google session refreshes without anonymous fallback")
 expect(auth.calls[-1].path.ends_with("grant_type=refresh_token"),"refresh uses Supabase session endpoint")
 auth.expires_at=0
 auth.responses=[{"error":"network_error"}]
 expect(not await auth.ensure_session() and auth.refresh_token=="test-refresh","offline refresh preserves recovery credential")
 auth.responses=[{"error":"request_rejected"}]
 expect(not await auth.ensure_session() and auth.refresh_token.is_empty(),"revoked refresh does not silently create anonymous identity")
 auth.sign_out()
 expect(not auth.signed_in() and auth.access_token.is_empty(),"sign-out clears local access and selects offline profile")
 auth.queue_free()
 await process_frame
 print("GOOGLE AUTH RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
