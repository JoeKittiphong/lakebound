extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://exports/size-audit/texture-before.json"))
 var failures := 0
 for record in records:
  var old_texture := load(record.before_path) as Texture2D
  var texture := load("res://" + str(record.source)) as Texture2D
  var previous := old_texture.get_image()
  var current := texture.get_image()
  if previous.is_compressed():
   previous.decompress()
  if current.is_compressed():
   current.decompress()
  previous.convert(Image.FORMAT_RGBA8)
  current.convert(Image.FORMAT_RGBA8)
  if previous.get_size() != current.get_size():
   previous.resize(current.get_width(), current.get_height(), Image.INTERPOLATE_LANCZOS)
  var error := 0.0
  var samples := 0
  for y in range(0, current.get_height(), 4):
   for x in range(0, current.get_width(), 4):
    var a := previous.get_pixel(x, y)
    var b := current.get_pixel(x, y)
    if a.a < 0.05:
     continue
    error += (a.r - b.r) ** 2 + (a.g - b.g) ** 2 + (a.b - b.b) ** 2
    samples += 3
  var psnr := -10.0 * log(maxf(error / maxf(1, samples), 0.000000000001)) / log(10.0)
  record["width"] = current.get_width()
  record["height"] = current.get_height()
  record["sampled_psnr_db"] = psnr
  record["after_bytes"] = FileAccess.get_file_as_bytes("res://" + str(record.cache)).size()
  var passed: bool = psnr >= 32.0 and record.after_bytes < record.before_bytes
  failures += int(not passed)
  print("PASS: " if passed else "FAIL: ", record.source, " PSNR=", psnr, " bytes ", record.before_bytes, " -> ", record.after_bytes)
 var file := FileAccess.open("res://exports/size-audit/texture-after.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(records, " "))
 file.close()
 print("TEXTURE SIZE RESULT: 3 checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
