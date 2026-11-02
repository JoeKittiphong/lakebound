extends SceneTree
func _initialize() -> void:
 var failures := 0
 var checks := 0
 var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/texture_budget.json"))
 for item in budget.textures:
  var texture: Texture2D = load("res://"+item.path)
  checks += 1
  if texture == null or texture.get_width()!=int(item.limit) or texture.get_height()!=int(item.limit):
   failures += 1
   push_error("Budget dimensions mismatch: "+item.path)
 for item in TackleCatalog.ITEMS:
  var icon: AtlasTexture = item.shop_icon
  checks += 1
  if icon.region.size!=Vector2(128,128) or not Rect2(Vector2.ZERO,icon.atlas.get_size()).encloses(icon.region):
   failures += 1
   push_error("Imported atlas coordinates invalid: "+String(item.id))
 print("TEXTURE BUDGET: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
