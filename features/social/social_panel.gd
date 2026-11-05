extends Control

signal opened
signal closed

@export var supabase_url: String = ""
@export var supabase_key: String = ""
var profile: AnglerProfile
var online_rows: Array = []
var online := false
var busy := false
var scope := "all"
var top_limit := 10
var ranking_sync := RankingSync.new()
var retry_attempt := 0
var displaying_cached := false
var background: Node
@onready var request: HTTPRequest = $Request

func _ready() -> void:
 if OS.has_feature("web"): request.accept_gzip=false
 profile = get_node_or_null("/root/AnglerSave")
 background = get_node_or_null("/root/RankingOnline")
 if background != null: background.scores_uploaded.connect(_background_uploaded)
 %Save.pressed.connect(_save)
 %Close.pressed.connect(close)
 %Refresh.pressed.connect(func(): retry_attempt = 0; $SyncRetry.stop(); _sync())
 $SyncRetry.timeout.connect(func():
  if visible: _sync())
 %Mode.tab_changed.connect(_mode_changed)
 %Filter.item_selected.connect(func(_index: int): _selection_changed())
 for limit in [10, 50, 100]:
  %TopLimit.add_item("Top %d" % limit)
 %TopLimit.item_selected.connect(func(index: int): top_limit = [10, 50, 100][index]; _selection_changed())
 request.request_completed.connect(_received)
 profile.changed.connect(_profile_changed)
 %Name.text_submitted.connect(func(_text: String): _save())
 %ConnectionSettings.pressed.connect(_open_connection_settings)
 %CancelEndpoint.pressed.connect(func(): %EndpointOverlay.hide())
 %SaveEndpoint.pressed.connect(_save_endpoint)
 %Mode.add_tab("รวมทุกแผนที่")
 %Mode.add_tab("อันดับแต่ละแผนที่")
 var config := ConfigFile.new()
 if config.load("res://online.cfg") == OK:
  supabase_url = str(config.get_value("supabase", "url", supabase_url))
  supabase_key = str(config.get_value("supabase", "publishable_key", supabase_key))
 supabase_url = SupabaseConnectionSettings.resolve(supabase_url)
 _mode_changed(0)

func open_for_map(map_id: String) -> void:
 _cancel_request()
 hide()
 _mode_changed(1)
 for index in %Filter.item_count:
  if str(%Filter.get_item_metadata(index)) == map_id:
   %Filter.select(index)
   break
 open()

func open() -> void:
 _cancel_request()
 retry_attempt = 0
 show()
 opened.emit()
 %Name.text = profile.data.identity.name
 %Identity.text = "รหัสผู้เล่น · " + str(profile.data.identity.id).left(8)
 %Close.disabled = false
 %ProfileOverlay.visible = profile.data.identity.name.is_empty()
 %Edit.show()
 %Message.show()
 _profile_changed()
 if profile.data.identity.name.is_empty():
  %Name.grab_focus()
 else:
  _sync()

func close() -> void:
 %ProfileOverlay.hide()
 if %EndpointOverlay.visible:
  %EndpointOverlay.hide()
  return
 if visible:
  _cancel_request()
  hide()
  closed.emit()

func _open_connection_settings() -> void:
 %Endpoint.text = supabase_url
 %EndpointMessage.text = "ใช้ที่อยู่ Supabase ของ Lakebound ที่ผู้ดูแลให้มา"
 %EndpointOverlay.show()

func _save_endpoint() -> void:
 if busy: return
 var address := SupabaseConnectionSettings.normalize(%Endpoint.text)
 if not SupabaseConnectionSettings.valid_url(address):
  %EndpointMessage.text = "ใส่ Supabase URL สำหรับระบบอันดับ"
  return
 if SupabaseConnectionSettings.save_url(address) != OK:
  %EndpointMessage.text = "บันทึกที่อยู่ไม่ได้ · ลองอีกครั้ง"
  return
 supabase_url = address
 if background != null and background.enabled: background.set_connection(supabase_url, supabase_key)
 ranking_sync.configure(supabase_url, str(profile.data.identity.id))
 _profile_changed()
 %EndpointOverlay.hide()
 _sync()

func _profile_changed() -> void:
 online = false
 displaying_cached = false
 %Status.text = "สถิติในเครื่อง · ยังไม่ได้เชื่อม Supabase" if supabase_url.is_empty() else "สถิติในเครื่อง · กดเชื่อมต่อเพื่ออัปเดตอันดับ"
 _render()

func _save() -> void:
 if not AnglerIdentity.valid_name(%Name.text):
  %Message.text = "ใช้ชื่อ 2–24 ตัวอักษร ไม่ใช้บรรทัดใหม่หรือ < > [ ]"
  return
 if not profile.set_display_name(%Name.text):
  %Message.text = profile.save_error
  return
 %Message.text = "บันทึกชื่อแล้ว · เล่นต่อได้โดยไม่ต้องใช้ Gmail"
 %Close.disabled = false
 %ProfileOverlay.hide()
 _sync()

func _mode_changed(index: int) -> void:
 %Mode.current_tab = index
 scope = ["all", "map"][index]
 %Filter.clear()
 %Filter.visible = index == 1
 if index == 1:
  for entry in RegionCatalog.MAPS:
   %Filter.add_item(entry.name)
   %Filter.set_item_metadata(%Filter.item_count - 1, entry.id)
 _selection_changed()

func _selection_changed() -> void:
 _cancel_request()
 retry_attempt = 0
 online = false
 displaying_cached = false
 _render()
 if is_node_ready() and visible: _sync()

func _selected_filter() -> String:
 return "" if scope == "all" else str(%Filter.get_item_metadata(%Filter.selected))

func _render() -> void:
 # Profile changes are frequent while fishing. Rebuild only the open panel.
 if not is_node_ready() or not is_visible_in_tree(): return
 for child in %Rows.get_children(): child.free()
 var filter := _selected_filter()
 var remote_rows := online or displaying_cached
 var local_best := AnglerIdentity.best(profile.ranking_records(), scope, filter)
 var records: Array = (online_rows if remote_rows else (local_best if supabase_url.is_empty() else [])).slice(0, top_limit)
 var title := "อันดับรวมทุกแผนที่" if scope == "all" else str(RegionCatalog.find(filter).name)
 %ScopeTitle.text = "%s · Top %d" % [title, top_limit]
 %HistorySummary.text = "จับสะสม %d ตัว · ประวัติ 10 ตัวใหญ่สุด/ชนิด" % profile.lifetime_catches()
 %Empty.visible = records.is_empty()
 %Empty.text = "ยังไม่มีสถิติในหมวดนี้ · ออกไปตกปลาตัวแรกกัน" if remote_rows or supabase_url.is_empty() else "ยังเทียบอันดับไม่ได้ในตอนนี้ · แตะแท็บเพื่อลองอีกครั้ง"
 %Personal.text = "ยังไม่มีสถิติของคุณในหมวดนี้"
 if not local_best.is_empty():
  %Personal.text = "สถิติในเครื่องของคุณ · %.3f กก." % float(local_best[0].weight)
 for index in records.size():
  var record: Dictionary = records[index]
  var mine: bool = not remote_rows or record.get("player_id", "") == profile.data.identity.id
  var player: String = str(record.get("player_name", profile.data.identity.name))
  var row := preload("res://features/social/ranking_row.tscn").instantiate()
  %Rows.add_child(row)
  var rank_number := index + 1
  row.get_node("Line/Rank").text = "%02d" % rank_number if remote_rows else "—"
  row.get_node("Line/Info").text = "%s%s" % [player, " · คุณ" if mine else ""]
  row.get_node("Line/Fish").text = str(record.get("name", record.species))
  row.get_node("Line/Location").text = str(RegionCatalog.find(record.map).name)
  row.get_node("Line/Weight").text = "%.3f กก." % float(record.weight)
  if mine:
   %Personal.text = "สถิติดีที่สุดของคุณ · %.3f กก.%s" % [float(record.weight), " · อันดับ %d" % rank_number if remote_rows else ""]

func _set_busy(value: bool) -> void:
 busy = value
 # A cached board is a fallback, not the result of the current comparison.
 %Comparing.visible = value and visible
 %Scroll.visible = not %Comparing.visible
 %Refresh.disabled = value
 %Save.disabled = value
 %Name.editable = not value
 %ConnectionSettings.disabled = value
 %SaveEndpoint.disabled = value

func _cancel_request() -> void:
 if busy: request.cancel_request()
 _set_busy(false)
 $SyncRetry.stop()

func _sync() -> void:
 if busy or supabase_url.is_empty() or profile.data.identity.name.is_empty(): return
 if not SupabaseConnectionSettings.valid_url(supabase_url):
  %Status.text = "ใช้ Supabase URL สำหรับระบบอันดับ"
  return
 ranking_sync.configure(supabase_url, str(profile.data.identity.id))
 _show_cached()
 _set_busy(true)
 %Status.text = "อันดับที่บันทึกไว้ · กำลังอัปเดตข้อมูลล่าสุด…" if displaying_cached else "กำลังเชื่อมต่อ…"
 # The persistent service is the only uploader when it is active. The open
 # panel owns an independent read/cache, so filter changes cannot race its batch.
 var use_background: bool = background != null and background.active_for(profile) and background.endpoint == supabase_url
 if AccountAuth.enabled and not AccountAuth.signed_in(): use_background=true
 var payload := ranking_sync.build_read(scope, _selected_filter(), top_limit) if use_background else ranking_sync.build(profile, scope, _selected_filter(), top_limit)
 # Public reads omit guest credentials. Every RPC uses HTTPS POST.
 var body := ranking_sync.rpc_body(payload)
 var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + supabase_key])
 if AccountAuth.signed_in(): headers.append("Authorization: Bearer "+AccountAuth.access_token)
 var error := request.request(supabase_url, headers, HTTPClient.METHOD_POST, body)
 if error != OK: _received(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func _background_uploaded() -> void:
 if not visible: return
 _cancel_request()
 _sync.call_deferred()

func _received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 _set_busy(false)
 var data: Variant = null
 if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() <= RankingSnapshot.MAX_RESPONSE_BYTES:
  var parser := JSON.new()
  if parser.parse(body.get_string_from_utf8()) == OK: data = parser.data
 var api_error := str(data.get("error", "")) if data is Dictionary else ""
 var retryable := result != HTTPRequest.RESULT_SUCCESS or code == 429 or code >= 500 or (code == 200 and (data == null or api_error in ["busy_retry", "write_failed_retry", "refresh_failed_retry", "snapshot_not_ready"]))
 var decoded := ranking_sync.accept(data) if data is Dictionary else {}
 if decoded.get("upload_only", false):
  if visible: _sync()
  return
 online = decoded.has("rows")
 if online:
  displaying_cached = false
  retry_attempt = 0
  $SyncRetry.stop()
  online_rows = decoded.rows
  %Status.text = "เชื่อมต่อ Supabase แล้ว · สถิติยังไม่ผ่านการรับรองป้องกันโกง"
 else:
  _show_cached()
  %Status.text = SupabaseConnectionSettings.failure_message(result, code, api_error) + " · แสดงสถิติในเครื่อง"
  if displaying_cached: %Status.text += " · มีอันดับที่บันทึกไว้"
  if retryable and visible and retry_attempt < 3:
   retry_attempt += 1
   %Comparing.visible = true
   %Scroll.visible = false
   $SyncRetry.start(randf_range(1.0, 3.0) * pow(2.0, retry_attempt - 1))
   %Status.text = "ระบบอันดับกำลังมีผู้ใช้งานมาก · กำลังรอลองใหม่ (%d/3)" % retry_attempt
   if displaying_cached: %Status.text += " · แสดงอันดับที่บันทึกไว้"
 _render()

func _show_cached() -> void:
 var cached := ranking_sync.cached_view(scope, _selected_filter(), top_limit)
 displaying_cached = not cached.is_empty()
 if displaying_cached:
  online_rows = cached.rows
  _render()


var comparison_elapsed := 0.0

func _process(delta: float) -> void:
 if not visible or not %Comparing.visible: return
 comparison_elapsed += delta
 for index in %ComparisonMarks.get_child_count():
  var bar: Control = %ComparisonMarks.get_child(index)
  bar.scale.y = 0.3 + 0.7 * (0.5 + 0.5 * sin(comparison_elapsed * 5.0 - index * 1.4))
