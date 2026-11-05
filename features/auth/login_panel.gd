extends Control
signal opened
signal closed
var auth: Node
func _ready() -> void:
 auth=get_node("/root/AccountAuth")
 auth.changed.connect(render)
 auth.authenticated.connect(close)
 %SaveName.pressed.connect(func(): auth.save_player_name(%PlayerName.text))
 %PlayerName.text_submitted.connect(func(_value: String): auth.save_player_name(%PlayerName.text))
 %Google.pressed.connect(func():
  if not auth.access_token.is_empty() and not auth.account_ready:
   auth.busy=true
   auth._load_account(auth._generation)
  else: auth.begin_google())
 %Cancel.pressed.connect(auth.cancel_login)
 %Offline.pressed.connect(func():
  if auth.choose_offline(): close())
 %SignOut.pressed.connect(auth.sign_out)
 %Close.pressed.connect(close)
 render()
func open() -> void:
 show()
 opened.emit()
 render()
func close() -> void:
 hide()
 closed.emit()
func render() -> void:
 %Status.text=auth.status
 %Email.text=auth.email if auth.account_ready else ""
 %NameSetup.visible=auth.needs_name
 %Description.visible=not auth.needs_name
 %PlayerName.editable=not auth.busy
 %SaveName.disabled=auth.busy
 %Google.visible=not auth.signed_in() and not auth.needs_name
 %Google.disabled=auth.busy
 %Google.text="กำลังเชื่อมต่อ…" if auth.busy else "เข้าสู่ระบบด้วย Google"
 %Offline.visible=not auth.signed_in() and not auth.needs_name
 %Offline.disabled=auth.restoring and not auth.waiting
 %SignOut.visible=auth.account_ready
 %Cancel.visible=auth.waiting
 %Close.visible=auth.signed_in() or auth._offline_chosen
