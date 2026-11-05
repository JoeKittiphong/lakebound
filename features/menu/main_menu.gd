extends Control
var selected_region := "river"
@export var privacy_policy_url: String = "https://zylaah-support.netlify.app/privacy"

func _ready() -> void:
 AnglerSave.shopping_locked=false
 $ShopPanel.bind(AnglerSave,null,null,$CommerceGateway)
 _select_region(str(get_tree().get_meta("selected_region", "river")))
 AnglerSave.changed.connect(_refresh_player_header)
 _refresh_player_header()
 Competition.get_node("Friends").changed.connect(_friends_badge)
 _friends_badge()
 if AccountAuth.enabled and not AccountAuth.signed_in() and not AccountAuth._offline_chosen:
  $LoginPanel.open.call_deferred()
 elif AnglerSave.data.identity.name.is_empty():
  $SocialPanel.open.call_deferred()

func _refresh_player_header() -> void:
 var player_name: String=str(AnglerSave.data.identity.name).strip_edges()
 if player_name.is_empty():player_name="ผู้เล่น"
 $SafeArea/Profile/Row/Name.text=player_name
 $SafeArea/Profile/Row/Name.tooltip_text=player_name

func _friends_badge() -> void:
 var state: Dictionary=Competition.get_node("Friends").state()
 var count: int=state.get("incoming",[]).size()+state.get("invites",[]).size()
 $SafeArea/CompetitionButton.text="แข่งขันกับเพื่อน"+(" · แจ้งเตือน %d" % count if count>0 else " · 2–5 คน")
func _select_region(id: String) -> void:
 var entry := RegionCatalog.find(id)
 selected_region = entry.id
 $SafeArea/PlayCard/Content/MapCarousel.set_region(selected_region)
 get_tree().set_meta("selected_region", selected_region)
 $SafeArea/PlayCard/Content/Location.text = entry.name
 $SafeArea/PlayCard/Content/Description.text = entry.subtitle
 $SafeArea/PlayCard/Content/Build.text = "ปลา %d รายการ · ภารกิจ %d รายการ" % [entry.fish_count,entry.mission_count]
func _notification(what: int) -> void:
 # Browser navigation to Google also emits close-request. Keep the PKCE
 # verifier until the callback; only the explicit Cancel button cancels OAuth.
 if what == NOTIFICATION_WM_CLOSE_REQUEST and OS.has_feature("web") and AccountAuth.waiting:
  return
 if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
  if $LoginPanel.visible:
   if AccountAuth.waiting: AccountAuth.cancel_login()
   elif AccountAuth.signed_in() or AccountAuth._offline_chosen: $LoginPanel.close()
   else: get_tree().quit()
  elif $ShopPanel.visible:
   $ShopPanel.close_top_layer()
  elif $MatchPanel.visible:
   $MatchPanel.close_top_layer()
  elif $SocialPanel.visible:
   $SocialPanel.close()
  else:
   get_tree().quit()

func _on_play_pressed() -> void:
 if not Competition.room.is_empty() or not Competition._pending_room.is_empty():
  $MatchPanel.open()
  return
 if AnglerSave.data.identity.name.is_empty():
  $SocialPanel.open()
  return
 $SafeArea/PlayCard/Content/PlayButton.disabled = true
 $SafeArea/PlayCard/Content/PlayButton.text = "กำลังเดินทาง..."
 # Keep only the path across the transition. Loading the map here keeps the
 # cinematic, menu textures and map resources resident at the same time.
 get_tree().set_meta("pending_map_scene", str(RegionCatalog.find(selected_region).scene))
 var error := get_tree().change_scene_to_file("res://features/loading/map_transition.tscn")
 if error != OK:
  $SafeArea/PlayCard/Content/PlayButton.disabled = false
  $SafeArea/PlayCard/Content/PlayButton.text = "ลองเข้าแหล่งน้ำอีกครั้ง"

func _on_privacy_pressed() -> void:
 var result := OS.shell_open(privacy_policy_url)
 $SafeArea/PrivacyButton.tooltip_text = "เปิดในเบราว์เซอร์" if result == OK else privacy_policy_url

func _on_competition_pressed() -> void:
 if not AccountAuth.signed_in():
  $LoginPanel.open()
 elif AnglerSave.data.identity.name.is_empty():
  $SocialPanel.open()
 else:
  $MatchPanel.open()
