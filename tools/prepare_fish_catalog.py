"""Author editable fish species resources and model scenes (not runtime code)."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# id, Thai label, weights, depth, bait, speed, pull, struggle, visual metres, preview tilt
SPECIES=[
 ('tilapia','ปลานิล',.5,1.8,(.5,2.4),('worm','dough'),1.05,.66,1.8,.50,12),
 ('snakehead','ปลาช่อน',1.2,3.5,(.6,3.4),('lure','worm'),1.5,.95,2.8,.70,12),
 ('catfish','ปลาดุก',.8,2.7,(3.,5.5),('worm','dough'),.85,.84,3.6,.60,12),
 ('golden_barb','ปลาตะเพียนทอง',.2,1.4,(.5,2.4),('dough','worm'),1.1,.62,2.,.35,12),
 ('gourami','ปลาแรด',.7,4.,(.8,3.),('dough','worm'),.8,.86,1.7,.55,12),
 ('featherback','ปลากราย',.5,3.5,(1.4,4.5),('lure','worm'),1.1,.92,2.4,.85,12),
 ('betta','ปลากัด',.01,.035,(.15,.8),('worm',),.55,.36,2.8,.15,12),
 ('lionhead_goldfish','ปลาทองหัวสิงห์',.08,.8,(.4,1.8),('dough','worm'),.55,.45,1.7,.24,12),
 ('koi','ปลาคาร์ปโค่ย',.4,4.,(.7,3.),('dough','worm'),1.,.82,2.1,.65,12),
 ('arowana','ปลาอะโรวาน่า',.5,4.,(.2,1.8),('lure','worm'),1.3,.98,2.5,.80,12),
 ('tigerfish','ปลาเสือตอ',.3,2.,(1.,3.5),('lure','worm'),1.15,.85,2.6,.40,12),
 ('hampala','ปลากระสูบขีด',.5,4.,(.6,3.),('lure','worm'),1.65,1.05,3.,.55,12),
 ('giant_catfish','ปลาบึก',5.,25.,(2.5,5.5),('dough','worm'),.9,1.12,1.6,1.5,12),
 ('redtail_catfish','ปลากดหางแดง',1.,10.,(2.,5.),('worm','lure'),1.05,1.08,2.4,.9,12),
 ('freshwater_eel','ปลาไหล',.2,2.,(2.5,5.),('worm',),.95,.76,3.5,.75,12),
 ('freshwater_stingray','ปลากระเบนน้ำจืด',.8,8.,(3.,5.5),('worm',),.75,1.02,1.8,1.,68),
]
for spec,label,low,high,depth,baits,speed,pull,struggle,length,tilt in SPECIES:
 scene=f'''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://world/pond/models/fish_model.gd" id="script"]
[ext_resource type="PackedScene" path="res://world/pond/models/glb/{spec}.glb" id="model"]

[node name="FishModel" type="Node3D"]
script = ExtResource("script")

[node name="Model" parent="." instance=ExtResource("model")]
'''
 (ROOT/'world/pond/models'/f'{spec}.tscn').write_text(scene,encoding='utf-8')
 bait_text=', '.join('"'+b+'"' for b in baits)
 resource=f'''[gd_resource type="Resource" script_class="FishSpecies" load_steps=4 format=3]

[ext_resource type="Script" path="res://data/fish/fish_species.gd" id="1"]
[ext_resource type="PackedScene" path="res://world/pond/models/{spec}.tscn" id="model"]
[ext_resource type="Texture2D" path="res://assets/fish/icons/{spec}.tres" id="icon"]

[resource]
script = ExtResource("1")
id = &"{spec}"
display_name = "{label}"
model_scene = ExtResource("model")
collection_icon = ExtResource("icon")
visual_length_m = {length}
preview_tilt_degrees = {tilt}.0
min_weight = {low}
max_weight = {high}
preferred_depth = Vector2({depth[0]}, {depth[1]})
bait_preferences = PackedStringArray({bait_text})
detection_radius = {8.0 if spec!='catfish' else 7.5}
swim_speed = {speed}
pull_strength = {pull}
struggle_frequency = {struggle}
body_scale = Vector3(1, 1, 1)
'''
 (ROOT/'data/fish'/f'{spec}.tres').write_text(resource,encoding='utf-8')
preloads=',\n '.join(f'preload("res://data/fish/{s[0]}.tres")' for s in SPECIES)
(ROOT/'data/fish/fish_catalog.gd').write_text('''class_name FishCatalog
extends RefCounted

const SPECIES: Array[Resource] = [
 '''+preloads+'''
]

static func find(id: StringName) -> Resource:
 for definition in SPECIES:
  if definition.id == id:
   return definition
 return null
''',encoding='utf-8')
for path in (ROOT/'world/pond/models/glb').glob('*.glb.import'):
 text=path.read_text(encoding='utf-8').replace('nodes/root_name=""','nodes/root_name="FishAssetRoot"')
 for a,b in [('meshes/generate_lods=true','meshes/generate_lods=false'),('meshes/create_shadow_meshes=true','meshes/create_shadow_meshes=false'),('meshes/light_baking=1','meshes/light_baking=0'),('animation/fps=30','animation/fps=24')]:text=text.replace(a,b)
 path.write_text(text,encoding='utf-8')
print(f'Authored {len(SPECIES)} species resources and scenes.')
(ROOT/'world/pond/fish_visual.tscn').write_text('''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://world/pond/fish_visual.gd" id="script"]
[ext_resource type="PackedScene" path="res://world/pond/models/tilapia.tscn" id="model"]

[node name="FishVisual" type="Node3D"]
script = ExtResource("script")

[node name="Model" parent="." instance=ExtResource("model")]
''',encoding='utf-8')
