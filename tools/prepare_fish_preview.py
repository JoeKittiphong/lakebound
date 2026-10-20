"""Author a saved, editor-visible preview scene of all sixteen fish models."""
import ast
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
tree=ast.parse((ROOT/'tools/prepare_fish_catalog.py').read_text(encoding='utf-8'))
species=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SPECIES' for t in n.targets))
text='[gd_scene load_steps=21 format=3]\n\n'
for row in species:
 text+=f'[ext_resource type="PackedScene" path="res://world/pond/models/{row[0]}.tscn" id="{row[0]}"]\n'
text+='''[ext_resource type="FontFile" path="res://shared/ui/fonts/noto_sans_thai.ttf" id="font"]

[sub_resource type="Environment" id="environment"]
background_mode = 1
background_color = Color(0.025, 0.06, 0.085, 1)
ambient_light_source = 3
ambient_light_color = Color(0.8, 0.88, 1, 1)
ambient_light_energy = 1.0
tonemap_mode = 2

[sub_resource type="StandardMaterial3D" id="backdrop"]
albedo_color = Color(0.035, 0.09, 0.12, 1)
roughness = 1.0

[sub_resource type="QuadMesh" id="quad"]
size = Vector2(20, 10)
material = SubResource("backdrop")

[node name="FishCatalogPreview" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("environment")

[node name="Light" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-30, -35, 0)
light_energy = 1.5

[node name="Camera" type="Camera3D" parent="."]
position = Vector3(0, 0, 7)
projection = 1
size = 4.8
current = true

[node name="Backdrop" type="MeshInstance3D" parent="."]
position = Vector3(0, 0, -0.6)
mesh = SubResource("quad")
'''
for i,row in enumerate(species):
 spec,label=row[:2];x=(i%4-1.5)*1.65;y=(1.5-i//4)*1.10
 text+=f'''
[node name="{spec}Pose" type="Node3D" parent="."]
position = Vector3({x}, {y}, 0)
rotation_degrees = Vector3({row[-1]}, 0, 0)

[node name="Model" parent="{spec}Pose" instance=ExtResource("{spec}")]
rotation_degrees = Vector3(0, 90, 0)

[node name="{spec}Label" type="Label3D" parent="."]
position = Vector3({x}, {y-.35}, 0.15)
font = ExtResource("font")
font_size = 24
pixel_size = 0.0026
text = "{label}"
outline_size = 3
'''
(ROOT/'world/pond/models/fish_catalog_preview.tscn').write_text(text,encoding='utf-8')
print('Authored editor-visible preview for sixteen species.')
