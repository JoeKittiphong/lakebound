extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var profile := AnglerProfile.new()
 profile.save_path = "user://shop-redesign-%d.cfg" % Time.get_ticks_usec()
 root.add_child(profile)
 profile.data.coins = 5000
 for id in ["medium_rod", "long_reel", "clear_line", "spinner", "floating_lure"]:
  assert(profile.buy(id), "buy " + id)
  assert(profile.equip(id), "equip " + id)
  assert(profile._valid(profile.data), "valid save after " + id)
 var row: Node = load("res://features/economy/tackle_row.tscn").instantiate()
 root.add_child(row)
 for item in TackleCatalog.ITEMS:
  row.bind(item, profile)
  assert(row.get_node("Content/Icon").texture != null, "icon " + str(item.id))
 print("SHOP REDESIGN RESULT: all purchases, equipment, save validation and icons passed")
 row.queue_free()
 profile.queue_free()
 quit()

