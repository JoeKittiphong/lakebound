extends SceneTree
func _initialize() -> void:
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://world/pond/models/encyclopedia/encyclopedia_manifest.json"))
 var atlas:=Image.create(2048,2048,false,Image.FORMAT_RGBA8);atlas.fill(Color(0,0,0,0))
 var index:=0
 for e: Dictionary in rows:
  if e.status!="new":continue
  var source_path: String="res://assets/fish/encyclopedia_icons/"+e.id+".png"
  if not FileAccess.file_exists(source_path):source_path=ProjectSettings.globalize_path("res://").path_join("../art/fish/encyclopedia-100/collection_icons/"+e.id+".png")
  var image:=Image.load_from_file(source_path)
  var x: int=index%8*256;var y: int=index/8*176
  atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(x,y+8))
  var text:='[gd_resource type="AtlasTexture" format=3]\n[ext_resource type="Texture2D" path="res://assets/fish/encyclopedia_icons/encyclopedia_atlas.png" id="atlas"]\n[resource]\natlas = ExtResource("atlas")\nregion = Rect2(%d,%d,256,176)\n'%[x,y]
  FileAccess.open("res://assets/fish/encyclopedia_icons/"+e.id+".tres",FileAccess.WRITE).store_string(text)
  index+=1
 assert(atlas.save_png("res://assets/fish/encyclopedia_icons/encyclopedia_atlas.png")==OK)
 print("PACKED ICONS: ",index);quit()
