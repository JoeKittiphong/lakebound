extends Control
var sample_profile: AnglerProfile

static func sample_records() -> Array:
 var records: Array = []
 var examples := [
  ["river","tilapia",1.8,"worm",1.5,0.55,14.0],
  ["river","tilapia",1.2,"dough",0.8,0.4,9.0],
  ["river","snakehead",3.4,"spinner",0.6,0.7,22.0],
  ["river","catfish",5.2,"worm",3.5,0.62,18.0],
  ["river","golden_barb",2.1,"dough",2.0,0.5,16.0],
  ["lotus_marsh","tilapia",1.1,"dough",0.7,0.45,10.0],
  ["forest_stream","hampala",2.3,"spinner",1.2,0.6,12.0]]
 for i in examples.size():
  var value: Array = examples[i]
  var species := FishCatalog.find(StringName(value[1]))
  records.append({"map":value[0],"species":value[1],"name":species.display_name,"weight":value[2],"bait_id":value[3],"bait":TackleCatalog.item(value[3]).display_name,
   "rod":"คันเบ็ดเบา","reel":"รอกพื้นฐาน","line":"เอ็นไนลอน","depth":value[4],"time":200.0-i,"settings":{"drag_strength":value[5],"cast_distance":value[6]}})
 return records

func _ready() -> void:
 sample_profile = AnglerProfile.new()
 sample_profile.data = sample_profile.defaults()
 sample_profile.data.journal = sample_records()
 $Margin/Content/Methods.bind(sample_profile)

func _exit_tree() -> void:
 if is_instance_valid(sample_profile): sample_profile.free()
