extends Control

signal opened
signal closed
const Row = preload("res://features/economy/tackle_row.tscn")
var profile: AnglerProfile
var fishing: FishingController
var pond: PondEcosystem
var commerce: CommerceGateway
var map_id := "river"

func _exit_tree() -> void:
 if is_instance_valid(profile) and profile.changed.is_connected(refresh):
  profile.changed.disconnect(refresh)
 if is_instance_valid(commerce) and commerce.status_changed.is_connected(refresh):
  commerce.status_changed.disconnect(refresh)

func bind(value: AnglerProfile, controller: FishingController, ecosystem: PondEcosystem, gateway: CommerceGateway) -> void:
 profile = value
 fishing = controller
 pond = ecosystem
 commerce = gateway
 profile.changed.connect(refresh)
 commerce.status_changed.connect(refresh)
 $Card/Content/Header/Close.pressed.connect(close)
 $Card/Content/Emergency.pressed.connect(func(): _report(profile.emergency_supplies(), "ได้รับชุดสำรองสำหรับตกต่อแล้ว"))
 $Card/Content/Tabs/Storage/Sell.pressed.connect(func(): _report(profile.sell_catches(), "ขายปลาแล้ว"))
 $Card/Content/Recovery/Choices/Discard.pressed.connect(func(): _report(profile.discard_lure(), "ยอมเสียเหยื่อแล้ว"))
 $Card/Content/Recovery/Choices/Diamonds.pressed.connect(func(): _report(profile.recover_with_diamonds(), "กู้คืนเหยื่อแล้ว"))
 $Card/Content/Recovery/Choices/Ad.pressed.connect(_request_ad)

func open() -> void:
 if profile == null:
  return
 show()
 refresh()
 opened.emit()

func close() -> void:
 if not visible:
  return
 hide()
 closed.emit()

func refresh() -> void:
 if profile == null or not visible:
  return
 $Card/Content/Wallet.text = "%d เหรียญ   •   %d เพชร   •   สายเหลือ %.1f ม. / รอก %.0f ม.   •   กล่อง %.1f / %.0f กก." % [profile.data.coins, profile.data.diamonds, profile.data.line_remaining, profile.equipped("reel").length, profile.box_weight(), profile.equipped("box").capacity]
 var rows := $Card/Content/Tabs/Tackle/Scroll/Rows
 if rows.get_child_count() == 0:
  for item in TackleCatalog.ITEMS:
   var row := Row.instantiate()
   rows.add_child(row)
   row.buy_requested.connect(func(id: String): _report(profile.buy(id), "ซื้อแล้ว"))
   row.equip_requested.connect(func(id: String):
    var ok := profile.equip(id)
    fishing.refresh_equipment()
    _report(ok, "เปลี่ยนอุปกรณ์แล้ว"))
 for index in TackleCatalog.ITEMS.size():
  rows.get_child(index).bind(TackleCatalog.ITEMS[index], profile)
 var lines := PackedStringArray()
 for record in profile.data.catches:
  lines.append("%s  %.2f กก.  ≈ %d เหรียญ" % [record.name, record.weight, maxi(1, int(round(record.weight * 35.0)))])
 $Card/Content/Tabs/Storage/Scroll/Items.text = "\n".join(lines) if not lines.is_empty() else "กล่องปลาว่าง — เก็บปลาหลังจับได้เพื่อนำมาขาย"
 $Card/Content/Tabs/Storage/Sell.disabled = profile.data.catches.is_empty()
 lines.clear()
 for index in range(profile.data.journal.size() - 1, maxi(-1, profile.data.journal.size() - 101), -1):
  var record: Dictionary = profile.data.journal[index]
  lines.append("%s • %.2f กก. • %s\nเหยื่อ %s • ลึก %.1f ม. • %s / %s / %s" % [record.name, record.weight, record.map, record.bait, record.depth, record.rod, record.reel, record.line])
 $Card/Content/Tabs/Journal/Scroll/Records.text = "\n\n".join(lines) if not lines.is_empty() else "ยังไม่มีข้อมูล — บันทึกจากการตกสำเร็จจริง"
 var boss := pond.boss()
 var boss_text := "ยังไม่มีจ้าวบ่อ"
 if boss != null:
  var discovered: bool = get_node("/root/FishCollection").stats(boss.species.id).count > 0
  boss_text = "จ้าวบ่อ: %s — %.2f กก." % [boss.species.display_name if discovered else "???", boss.weight]
 $Card/Content/Tabs/Map/Info.text = "%s\nพิชิตจ้าวบ่อแล้ว %d ครั้ง\n\n%s\nสถิติในสมุดเป็นข้อมูลส่วนตัวบนเครื่องนี้" % [boss_text, profile.data.boss_history.size(), commerce.status]
 var pending: Dictionary = profile.data.pending
 $Card/Content/Recovery.visible = not pending.is_empty()
 if not pending.is_empty():
  $Card/Content/Recovery/Title.text = "สายขาด — %s สูญหาย (กู้คืนเฉพาะเหยื่อ ไม่คืนสายเอ็น)" % TackleCatalog.item(pending.lure).display_name
  $Card/Content/Recovery/Choices/Diamonds.text = "ใช้ %d เพชร" % pending.cost
  $Card/Content/Recovery/Choices/Diamonds.disabled = profile.data.diamonds < pending.cost
  $Card/Content/Recovery/Choices/Ad.disabled = not commerce.ad_available()
 $Card/Content/Emergency.disabled = profile.data.coins >= 20 or not profile.data.catches.is_empty() or not pending.is_empty() or (profile.quantity("worm") + profile.quantity("dough") > 0 and profile.data.line_remaining >= 1.0)
 $Card/Content/Message.text = profile.save_error if not profile.save_error.is_empty() else commerce.status

func _report(ok: bool, message: String) -> void:
 refresh()
 $Card/Content/Message.text = message if ok else profile.save_error if not profile.save_error.is_empty() else "ทำรายการไม่ได้ — ตรวจยอดเงิน จำนวน และพื้นที่เก็บปลา"

func _request_ad() -> void:
 if not profile.data.pending.is_empty():
  commerce.request_recovery(str(profile.data.pending.id))

func _input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  close()
  get_viewport().set_input_as_handled()
