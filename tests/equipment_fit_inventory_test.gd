extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: "+message)
func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.save_path="res://../output/guide-line-fit-v01/fit_inventory.cfg"
 var before: Dictionary=profile.data.duplicate(true)
 expect(not profile.equip("casting_rod") and profile.data==before,"unowned or unmatched selection cannot change inventory")
 profile.data.stock.casting_rod=1
 before=profile.data.duplicate(true)
 expect(not profile.equip("casting_rod") and profile.data==before,"rod cannot equip without an owned compatible reel")
 expect(profile.equipment_fit_error(TackleCatalog.item("casting_rod")).contains("รอกเบท"),"shop explains required reel family")
 profile.data.stock.baitcasting_reel=1
 expect(profile.equip("casting_rod") and profile.equipped("reel").id==&"baitcasting_reel","rod atomically selects an owned compatible reel")
 before=profile.data.duplicate(true)
 expect(not profile.equip("basic_reel") and profile.data==before,"incompatible reel is rejected without spending or changing gear")
 expect(profile.equip("light_rod") and profile.equipped("reel").id==&"basic_reel","switching back restores owned spinning reel")
 expect(profile.grant_trial_equipment(),"trial grants all families")
 for item in TackleCatalog.ITEMS:
  if item.kind!="rod":continue
  var stock: Dictionary=profile.data.stock.duplicate()
  var coins: int=profile.data.coins
  expect(profile.equip(str(item.id)),"every owned rod selects a complete compatible loadout")
  expect(item.mount_layout=="fixed" or EquipmentFit.compatible(item,profile.equipped("reel")),"equipped pair always matches geometry")
  expect(profile.data.stock==stock and profile.data.coins==coins,"auto pairing never grants or buys a reel")
 expect(ProfileStore.valid(profile.data),"new pairs retain existing save schema")
 var saved:=ProfileStore.load_profile(profile.save_path)
 expect(not saved.incompatible and saved.data.equipped==profile.data.equipped,"paired loadout survives reload")
 profile.data.equipped.rod="casting_rod";profile.data.equipped.reel="basic_reel"
 var money: int=profile.data.coins
 expect(profile.repair_equipment_fit() and profile.equipped("reel").reel_family in ["low","round"],"legacy mismatched pair reuses owned gear")
 expect(profile.data.coins==money,"legacy correction is free and does not mint currency")
 profile.data=profile.defaults();profile.data.stock.casting_rod=1;profile.data.equipped.rod="casting_rod"
 expect(profile.repair_equipment_fit() and profile.equipped("rod").id==&"light_rod","old save without a matching reel falls back to its owned spinning rod")
 profile.data.pending={"id":"pending","lure":"minnow","cost":TackleCatalog.item("minnow").recovery_cost}
 before=profile.data.duplicate(true)
 expect(not profile.equip("light_rod") and profile.data==before,"pair selection cannot bypass pending lure recovery")
 print("EQUIPMENT FIT INVENTORY: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
