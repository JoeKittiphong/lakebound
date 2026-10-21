extends SceneTree
func _initialize() -> void:
 var img := Image.load_from_file("res://../art/environment/river-sky-v01/sky-panorama-source.png")
 # Technical runtime export: retain the generated panorama, reduce resolution and encode JPEG.
 img.resize(512,256,Image.INTERPOLATE_LANCZOS)
 var out := "res://assets/environment/river/sky_panorama_512.jpg"
 assert(img.save_jpg(out,.72)==OK)
 print("SKY RUNTIME JPEG: ",FileAccess.get_file_as_bytes(out).size()," bytes; ",img.get_size())
 quit()
