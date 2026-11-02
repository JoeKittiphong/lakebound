extends Control
signal close_requested
const ZONES := {2:"คันเบ็ด",3:"รอก",1:"เหยื่อ",4:"สายเอ็น",5:"กล่องปลา"}
const KINDS := {2:["rod"],3:["reel"],1:["bait","lure"],4:["line"],5:["box"]}
const GEAR := {"Rod":"rod","Reel":"reel","Line":"line","Bait":"bait","Box":"box"}
var profile:AnglerProfile
var fishing:FishingController
var commerce:CommerceGateway
var category:=2
var trials_enabled:=true
@onready var browser:ShopShelfBrowser=%Shelf
@onready var inspector:Control=%EquipmentInspector
func _ready()->void:
 %Close.pressed.connect(func():close_requested.emit())
 browser.item_pressed.connect(_inspect_item)
 resized.connect(_layout_workspace)
 browser.page_changed.connect(_page_changed)
 %Previous.pressed.connect(func():browser.change_page(-1))
 %Next.pressed.connect(func():browser.change_page(1))
 %Owned.toggled.connect(func(_value:bool):refresh(true))
 var zones:PopupMenu=%Zone.get_popup()
 for key in ZONES:zones.add_item(ZONES[key],key)
 zones.id_pressed.connect(set_category)
 var more:PopupMenu=%More.get_popup()
 more.add_item("ยอดเงิน",5)
 more.set_item_disabled(0,true)
 more.add_check_item("เฉพาะของที่มี",50)
 for entry in [[10,"สมุดตกปลา"],[20,"รับชุดทดลองทุกประเภท"],[30,"ชุดสำรองฟรี"],[40,"กู้เหยื่อปลอม"]]:more.add_item(entry[1],entry[0])
 more.id_pressed.connect(_more)
 %Gear.pressed.connect(func():%Loadout.show();_show_rig(false);_inspect_item(profile.equipped("rod"));refresh())
 inspector.unequip_requested.connect(func(slot:String):
  _report(profile.unequip(slot),"ถอดอุปกรณ์แล้ว — เก็บไว้ในกระเป๋า",true))
 %LoadoutView.item_pressed.connect(_inspect_item)
 for key in ["Rod","Reel","Line","Bait","Box"]:
  var component_key:String=key.to_lower()
  get_node("%Select"+key).pressed.connect(func():_select_component(component_key))
  get_node("%Remove"+key).pressed.connect(func():_report(profile.unequip(component_key),"ถอดอุปกรณ์แล้ว — เก็บไว้ในกระเป๋า",true))
 %LoadoutSettings.pressed.connect(func():_show_rig(not %RigPanel.visible))
 %CloseRig.pressed.connect(func():_show_rig(false))
 %CloseLoadout.pressed.connect(func():_show_rig(false);%Loadout.hide())
 %Loadout.resized.connect(_layout_rig)
 %CloseJournal.pressed.connect(func():%Journal.hide())
 %CloseRecovery.pressed.connect(func():%Recovery.hide())
 %Rig.item_selected.connect(func(index:int):
  var rigs:Array=profile.equipped("bait").terminal_rigs if profile.equipped("bait") != null else []
  if index>=0 and index<rigs.size():_report(profile.select_rig(str(rigs[index].id)),"เปลี่ยนชุดปลายสายแล้ว",true))
 inspector.buy_requested.connect(func(id:String):_report(profile.buy(id),"ซื้อแล้ว — เลือกใช้ได้จากหน้าสินค้านี้"))
 inspector.equip_requested.connect(func(id:String):
  profile.save_error=""
  var item:=TackleCatalog.item(id)
  var ok:=profile.equip(id)
  _report(ok,"เปลี่ยนอุปกรณ์แล้ว",true)
  if ok and item.kind in ["rod","reel","line"]:
   set_category(4 if item.kind=="reel" or (item.kind=="rod" and item.mount_layout=="fixed") else 3 if item.kind=="rod" else 1))
 %Discard.pressed.connect(func():_report(profile.discard_lure(),"สละเหยื่อแล้ว"))
 %Diamonds.pressed.connect(func():_report(profile.recover_with_diamonds(),"กู้คืนเหยื่อแล้ว"))
 %Ad.pressed.connect(func():
  if not profile.data.pending.is_empty():commerce.request_recovery(str(profile.data.pending.id)))
func bind(value:AnglerProfile,controller:FishingController,gateway:CommerceGateway)->void:
 if is_instance_valid(profile) and profile.changed.is_connected(refresh):profile.changed.disconnect(refresh)
 if is_instance_valid(commerce) and commerce.status_changed.is_connected(refresh):commerce.status_changed.disconnect(refresh)
 profile=value;fishing=controller;commerce=gateway;inspector.profile=profile
 browser.profile=profile
 profile.changed.connect(refresh);commerce.status_changed.connect(refresh)
 %Methods.bind(profile)
func enter()->void:
 _layout_workspace()
 inspector.show()
 refresh(true)
 if not profile.data.pending.is_empty():%Recovery.show()
func leave()->void:
 inspector.close();_show_rig(false);%Loadout.hide();%Journal.hide();%Recovery.hide();browser.release_models()
func _show_rig(value:bool)->void:
 %RigPanel.visible=value
 _layout_rig()
func _layout_rig()->void:
 if not is_node_ready():return
 var width:=minf(clampf(size.x*.32,300,420),size.x*.42)
 var rig_width:=minf(320,size.x*.28) if %RigPanel.visible else 0.0
 %RigPanel.offset_right=-width
 %RigPanel.offset_left=-width-rig_width
 %LoadoutView.offset_right=-width-rig_width
 %LoadoutControls.offset_right=-width-rig_width
func _layout_workspace()->void:
 if not is_node_ready():return
 var width:=minf(clampf(size.x*.32,300,420),size.x*.42)
 inspector.offset_left=-width
 browser.offset_right=-width
 $Floating.offset_right=-width
 _layout_rig()
func _inspect_item(item:TackleItem)->void:
 inspector.allow_unequip = %Loadout.visible
 if item == null:
  inspector.close()
  return
 inspector.open_item(item)
 browser.selected_id=str(item.id)
 browser.refresh_badges()
func _select_component(key:String)->void:
 _show_rig(false);%Loadout.hide()
 set_category({"rod":2,"reel":3,"line":4,"bait":1,"box":5}.get(key,2))
func set_category(index:int)->void:
 category=index if ZONES.has(index) else 2
 if is_node_ready():%Loadout.hide();_show_rig(false)
 refresh(true)
func refresh(reset_page:=false)->void:
 if profile==null or not is_visible_in_tree():return
 %Wallet.text="%d เหรียญ · %d เพชร"%[profile.data.coins,profile.data.diamonds]
 %CurrentRod.text="คันที่ใช้: "+profile.equipment_name("rod")
 %Zone.text=({2:"1 คันเบ็ด",3:"2 รอก",4:"3 เอ็น",1:"4 เหยื่อ",5:"กล่องปลา"}[category])+" · เลือกหมวด"
 var entries:Array[TackleItem]=[]
 for item in TackleCatalog.ITEMS:
  if item.kind not in KINDS[category]:continue
  var count:int=profile.spare_line_count(str(item.id)) if item.kind=="line" else profile.quantity(str(item.id))
  if %Owned.button_pressed and count<=0 and str(profile.data.equipped.line)!=str(item.id):continue
  entries.append(item)
 if category in [3,4,1]:entries.sort_custom(func(a:TackleItem,b:TackleItem):return int(not EquipmentChoiceRules.error(profile,a).is_empty())<int(not EquipmentChoiceRules.error(profile,b).is_empty()))
 if category==5:entries.sort_custom(func(a:TackleItem,b:TackleItem):return a.capacity<b.capacity)
 if reset_page or browser.items!=entries:browser.set_items(entries,category==2,not reset_page)
 elif browser.slots().all(func(slot:ShopShelfSlot):return slot.item==null) and not entries.is_empty():browser.set_items(entries,category==2,true)
 %ZoneCount.text="%d รายการ%s"%[entries.size()," · ในกระเป๋า" if %Owned.button_pressed else ""]
 browser.get_node("Empty").visible=entries.is_empty()
 if not %Loadout.visible and (inspector.selected_item==null or inspector.selected_item not in entries):
  var equipped:TackleItem=profile.equipped({2:"rod",3:"reel",4:"line",1:"bait",5:"box"}[category])
  if equipped in entries:_inspect_item(equipped)
  elif not entries.is_empty():_inspect_item(entries[0])
 browser.refresh_badges()
 _page_changed()
 var active:=profile.current_rig()
 %Rig.clear()
 var rigs:Array = profile.equipped("bait").terminal_rigs if profile.equipped("bait") != null else []
 for rig in rigs:
  var result:=profile.rig_result(rig)
  var index:int=%Rig.item_count
  %Rig.add_item("%s · %.1f g%s"%[rig.display_name,result.payload_g,"" if result.allowed else " · ใช้ไม่ได้"])
  %Rig.set_item_disabled(index,not result.allowed)
  %Rig.set_item_tooltip(index,RigCompatibility.summary(result))
  if rig==active:%Rig.select(index)
 %Rig.disabled=not profile.data.pending.is_empty() or rigs.is_empty()
 %RigStatus.text=RigCompatibility.summary(profile.rig_result())
 %LoadoutView.set_profile(profile)
 %SelectReel.disabled=profile.equipped("rod") == null or profile.equipped("rod").mount_layout=="fixed"
 var missing := PackedStringArray()
 for key in GEAR:
  var slot: String = GEAR[key]
  var empty := profile.equipped(slot) == null
  get_node("%Select"+key).text = {"rod":"คัน","reel":"รอก","line":"เอ็น","bait":"เหยื่อ","box":"กล่อง"}[slot]+(" · ว่าง" if empty else "")
  var remove_button: Button = get_node("%Remove"+key)
  remove_button.disabled = empty or not profile.data.pending.is_empty() or (slot == "box" and profile.box_weight() > 0)
  remove_button.tooltip_text = "นำปลาออกจากกล่องก่อนถอด" if slot == "box" and profile.box_weight() > 0 else "เก็บอุปกรณ์กลับเข้ากระเป๋า"
  if empty: missing.append({"rod":"คัน","reel":"รอก","line":"เอ็น","bait":"เหยื่อ","box":"กล่อง"}[slot])
 %LoadoutHint.text = "ยังไม่ได้ใส่: "+" · ".join(missing) if not missing.is_empty() else "แตะอุปกรณ์เพื่อดูรายละเอียดหรือถอดออก"
 inspector.allow_unequip = %Loadout.visible
 var menu:PopupMenu=%More.get_popup()
 menu.set_item_text(menu.get_item_index(5),%Wallet.text)
 menu.set_item_checked(menu.get_item_index(50),%Owned.button_pressed)
 menu.set_item_disabled(menu.get_item_index(20),not trials_enabled or not profile.data.pending.is_empty())
 menu.set_item_disabled(menu.get_item_index(30),profile.data.coins>=20 or not profile.data.catches.is_empty() or not profile.data.pending.is_empty() or (profile.quantity("worm")+profile.quantity("dough")>0 and profile.data.line_remaining>=1))
 menu.set_item_disabled(menu.get_item_index(40),profile.data.pending.is_empty())
 if profile.data.pending.is_empty():%Recovery.hide()
 else:
  %RecoveryTitle.text="สายขาด · %s รอกู้คืน\nคืนเฉพาะเหยื่อ ไม่คืนสายเอ็น"%TackleCatalog.item(str(profile.data.pending.lure)).display_name
  %Diamonds.text="กู้คืน · %d เพชร"%profile.data.pending.cost
  %Diamonds.disabled=profile.data.diamonds<int(profile.data.pending.cost)
  %Ad.disabled=not commerce.ad_available()
 inspector.refresh()
func _page_changed()->void:
 %Pager.text="%02d / %02d"%[browser.page+1,browser.page_count()]
 %Previous.disabled=browser.page<=0
 %Next.disabled=browser.page>=browser.page_count()-1
func _report(ok:bool,message:String,equipment_changed:=false)->void:
 if ok and equipment_changed:fishing.refresh_equipment()
 refresh()
 %Message.text=message if ok else profile.save_error if not profile.save_error.is_empty() else "ทำรายการไม่ได้ — ตรวจจำนวน เงิน และความเข้ากันได้ของอุปกรณ์"
 if inspector.visible:inspector.show_feedback(ok,%Message.text)
func _more(id:int)->void:
 match id:
  10:%Journal.show()
  20:_report(profile.grant_trial_equipment(),"รับชุดทดลองแล้ว — เปิดเฉพาะของที่มีเพื่อเลือกใช้")
  30:_report(profile.emergency_supplies(),"ได้รับชุดสำรองแล้ว",true)
  40:%Recovery.show()
  50:%Owned.button_pressed=not %Owned.button_pressed
func pop_layer()->bool:
 if %RigPanel.visible:_show_rig(false);return true
 for overlay in [%Recovery,%Journal,%Loadout]:
  if overlay.visible:overlay.hide();return true
 return false
