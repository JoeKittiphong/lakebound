"""Author modern SVG assets and editable HUD scenes; never runs inside the game."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/ui/modern'
OUT.mkdir(parents=True,exist_ok=True)
icons={
'book':'<path d="M6 5h19v23H6a3 3 0 0 1 0-6h19M6 5a3 3 0 0 0-3 3v17M9 5v17"/><path d="M13 13c3-4 6-4 8 0-2 4-5 4-8 0Zm0 0-3-2v4Z"/>',
'help':'<circle cx="16" cy="16" r="12"/><path d="M12 12a4 4 0 0 1 8 0c0 3-4 3-4 6"/><path d="M16 23h.01"/>',
'back':'<path d="m19 7-9 9 9 9M10 16h16"/>',
'cast':'<path d="M5 27 19 9M9 25 22 8M19 9l4-4c6 1 6 8 2 12"/><path d="M25 17v5a3 3 0 0 1-6 0v-2l3 2"/>',
'hook':'<path d="M19 4v17a7 7 0 0 1-14 0v-6l5 4"/><circle cx="19" cy="5" r="2"/>',
'cancel':'<path d="m9 9 14 14M23 9 9 23"/>',
'depth':'<path d="M4 7h24M16 11v16m-5-5 5 5 5-5M5 14h4M5 20h4"/>',
'worm':'<path d="M7 25c-5-7 8-6 4-13S13 1 18 6s-5 9-1 13 11-3 9-8"/><path d="m8 20 4 2m-2-7 4-1m1-7 4 2m0 10 1 4"/>',
'dough':'<circle cx="12" cy="19" r="7"/><circle cx="22" cy="20" r="6"/><circle cx="17" cy="10" r="7"/>',
'lure':'<path d="M5 17c6-9 16-11 21-4-3 9-16 12-21 4Zm0 0-3-5v10Z"/><path d="M21 20v6a3 3 0 0 1-6 0v-2"/><circle cx="22" cy="13" r="1"/>',
'fish':'<path d="M5 16c6-9 16-9 22 0-6 9-16 9-22 0Zm0 0-3-5v10Z"/><circle cx="22" cy="14" r="1"/>',
'keep':'<path d="M6 13h20l-2 14H8L6 13Zm4 0 6-9 6 9M12 18v5m8-5v5"/>',
'release':'<path d="M7 17c5-6 11-6 16 0-5 6-11 6-16 0Zm0 0-4-4v8ZM20 5h8m-4-4 4 4-4 4M4 28c3-3 5 3 8 0s5 3 8 0 5 3 8 0"/>',
'clock':'<circle cx="16" cy="16" r="11"/><path d="M16 8v8l5 3"/>',
'line':'<path d="M7 6v20m18-20v20M7 16h18m-5-5 5 5-5 5m-8-10-5 5 5 5"/>',
}
for name,body in icons.items():
 (OUT/f'{name}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#e9f5fa" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'+body+'</g></svg>',encoding='utf8')
for name,fill,border in [('panel','#101e2b','#344a5a'),('button','#142635','#435a6b'),('pressed','#244859','#6ce5da'),('accent','#167c7b','#74f0df'),('slot','#142432','#344c5d'),('selected','#1c3d48','#6de3d6')]:
 (OUT/f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><rect x="1" y="1" width="94" height="94" rx="18" fill="{fill}" fill-opacity=".94" stroke="{border}" stroke-width="2"/></svg>',encoding='utf8')
 (OUT/f'{name}.tres').write_text(f'''[gd_resource type="StyleBoxTexture" load_steps=2 format=3]
[ext_resource type="Texture2D" path="res://assets/ui/modern/{name}.svg" id="texture"]
[resource]
texture = ExtResource("texture")
texture_margin_left = 20.0
texture_margin_top = 20.0
texture_margin_right = 20.0
texture_margin_bottom = 20.0
content_margin_left = 12.0
content_margin_top = 10.0
content_margin_right = 12.0
content_margin_bottom = 10.0
''',encoding='utf8')
base=(ROOT/'shared/ui/game_theme.tres').read_text(encoding='utf8')
base=base.replace('Color(0.025, 0.12, 0.14, 1)','Color(0.92, 0.97, 1, 1)')
base=base.replace('Color(0.39, 0.89, 0.75, 1)','Color(0.08, 0.15, 0.21, 0.94)').replace('Color(0.61, 1, 0.86, 1)','Color(0.14, 0.28, 0.34, 1)').replace('Color(0.025, 0.085, 0.105, 0.88)','Color(0.04, 0.08, 0.12, 0.94)')
base=base.replace('default_font_size = 20','default_font_size = 18').replace('Button/font_sizes/font_size = 24','Button/font_sizes/font_size = 18')
(OUT/'hud_theme.tres').write_text(base,encoding='utf8')
p=ROOT/'features/fishing/fishing_hud.tscn'
s=p.read_text(encoding='utf8')
if 'id="i_book"' in s:
 print('Refreshed modern vector assets. Existing authored scenes were preserved.')
 raise SystemExit(0)
s=s.replace('res://shared/ui/game_theme.tres','res://assets/ui/modern/hud_theme.tres')
s=s.replace('res://assets/ui/collection/button.tres','res://assets/ui/modern/button.tres').replace('res://assets/ui/collection/button_pressed.tres','res://assets/ui/modern/pressed.tres')
def edit(name,parent,props):
 global s
 pat=r'(\[node name="'+re.escape(name)+r'"[^\n]* parent="'+re.escape(parent)+r'"[^\n]*\]\n)(.*?)(?=\n\[|\Z)'
 match=re.search(pat,s,re.S)
 if not match: raise ValueError((name,parent))
 body=match[2]
 for key,value in props.items():
  line=f'{key} = {value}'
  body=re.sub(r'^'+re.escape(key)+r' = .*$',lambda _:line,body,flags=re.M) if re.search(r'^'+re.escape(key)+r' = ',body,re.M) else body.rstrip()+'\n'+line+'\n'
 s=s[:match.start()]+match[1]+body+s[match.end():]
def rect(name,parent,x,y,w,h,ax=0,ay=0):
 edit(name,parent,{'anchor_left':str(ax),'anchor_right':str(ax),'anchor_top':str(ay),'anchor_bottom':str(ay),'offset_left':str(x),'offset_top':str(y),'offset_right':str(x+w),'offset_bottom':str(y+h)})
ext=''
for name in icons:
 ext+=f'[ext_resource type="Texture2D" path="res://assets/ui/modern/{name}.svg" id="i_{name}"]\n'
for name in ['button','pressed','accent','panel']:
 ext+=f'[ext_resource type="StyleBox" path="res://assets/ui/modern/{name}.tres" id="m_{name}"]\n'
s=s.replace('[sub_resource type="Environment"',ext+'\n[sub_resource type="Environment"',1)
def button(name,parent,icon,tip):
 edit(name,parent,{'text':'""','icon':f'ExtResource("i_{icon}")','tooltip_text':f'"{tip}"','expand_icon':'true','icon_alignment':'1','theme_override_constants/icon_max_width':'28','theme_override_styles/normal':'ExtResource("m_button")','theme_override_styles/hover':'ExtResource("m_pressed")','theme_override_styles/pressed':'ExtResource("m_pressed")'})
button('CollectionButton','SafeArea','book','สมุดสะสมปลา')
rect('CollectionButton','SafeArea',0,0,64,64)
button('EcologyButton','SafeArea','help','วิธีเล่นและปลาในบ่อ')
rect('EcologyButton','SafeArea',76,0,64,64)
button('BackButton','SafeArea','back','หน้าหลัก')
rect('BackButton','SafeArea',-64,0,64,64,1,0)
button('ActionButton','SafeArea','cast','เหวี่ยงเบ็ด')
rect('ActionButton','SafeArea',-144,-312,88,80,1,1)
edit('ActionButton','SafeArea',{'theme_override_styles/normal':'ExtResource("m_accent")','theme_override_constants/icon_max_width':'36'})
button('CancelButton','SafeArea','cancel','เก็บเบ็ด')
rect('CancelButton','SafeArea',-330,-84,64,64,1,1)
edit('Location','SafeArea',{'visible':'false'})
for name in ['MoveLabel','RodInstructions']:
 edit(name,'SafeArea',{'visible':'false'})
rect('Status','SafeArea',-120,0,240,52,.5,0)
edit('Status','SafeArea',{'visible':'false','theme_override_styles/panel':'ExtResource("m_panel")'})
edit('State','SafeArea/Status/Content',{'text':'"รอปลา"','theme_override_font_sizes/font_size':'18'})
edit('Message','SafeArea/Status/Content',{'visible':'false'})
rect('EcologyPanel','SafeArea',0,80,390,480)
edit('Guide','SafeArea/EcologyPanel/Content',{'text':'"จอยซ้าย: เดิน\\nจอยขวา: เล็ง แล้วปล่อยเพื่อเหวี่ยง\\nปลากินเบ็ด: แตะรูปเบ็ด\\nสู้ปลา: ดึงลงเก็บสาย ดันขึ้นผ่อนสาย\\nลากพื้นที่ว่างด้านขวา: หมุนกล้อง"'})
rect('LineInfo','SafeArea',-144,-70,144,60,1,.5)
edit('Distance','SafeArea/LineInfo/Content',{'text':'"14.0 m"','theme_override_font_sizes/font_size':'18','horizontal_alignment':'1'})
edit('Reel','SafeArea/LineInfo/Content',{'visible':'false'})
rect('TensionText','SafeArea',-210,-260,190,32,1,1)
edit('TensionText','SafeArea',{'text':'"45%"','theme_override_font_sizes/font_size':'18'})
rect('BaitPanel','SafeArea',-192,-260,384,148,.5,1)
edit('BaitPanel','SafeArea',{'visible':'false'})
edit('Depth','SafeArea/BaitPanel/Content/DepthRow',{'custom_minimum_size':'Vector2(160, 48)'})
edit('Eyebrow','ResultLayer/Card/Content',{'visible':'false'})
edit('FishName','ResultLayer/Card/Content',{'theme_override_font_sizes/font_size':'28'})
edit('Description','ResultLayer/Card/Content',{'text':'"บันทึกแล้ว"','theme_override_font_sizes/font_size':'16'})
for name,icon,label in [('KeepButton','keep','เก็บ'),('ReleaseButton','release','ปล่อย')]:
 button(name,'ResultLayer/Card/Content',icon,label)
 edit(name,'ResultLayer/Card/Content',{'text':f'"{label}"','theme_override_constants/icon_max_width':'24','theme_override_constants/h_separation':'12','icon_alignment':'0'})
# New authored controls, not runtime construction.
s+='''
[node name="BaitDock" type="HBoxContainer" parent="SafeArea"]
layout_mode = 1
anchor_left = 0.5
anchor_right = 0.5
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = -86.0
offset_top = -80.0
offset_right = 86.0
offset_bottom = -16.0
theme_override_constants/separation = 12
mouse_filter = 2

[node name="BaitButton" type="Button" parent="SafeArea/BaitDock"]
layout_mode = 2
custom_minimum_size = Vector2(64, 64)
icon = ExtResource("i_worm")
expand_icon = true
icon_alignment = 1
focus_mode = 0
tooltip_text = "ไส้เดือน"
theme_override_constants/icon_max_width = 28
theme_override_styles/normal = ExtResource("m_button")
theme_override_styles/hover = ExtResource("m_pressed")
theme_override_styles/pressed = ExtResource("m_pressed")

[node name="DepthButton" type="Button" parent="SafeArea/BaitDock"]
layout_mode = 2
custom_minimum_size = Vector2(100, 64)
icon = ExtResource("i_depth")
text = "1.5"
expand_icon = true
focus_mode = 0
tooltip_text = "ปรับความลึก (เมตร)"
theme_override_constants/icon_max_width = 24
theme_override_styles/normal = ExtResource("m_button")
theme_override_styles/hover = ExtResource("m_pressed")
theme_override_styles/pressed = ExtResource("m_pressed")

[node name="Toast" type="Label" parent="SafeArea"]
layout_mode = 1
anchor_left = 0.5
anchor_right = 0.5
offset_left = -220.0
offset_right = 220.0
offset_top = 72.0
offset_bottom = 112.0
text = ""
horizontal_alignment = 1
theme_override_font_sizes/font_size = 18
theme_override_constants/outline_size = 5
theme_override_colors/font_outline_color = Color(0.02, 0.04, 0.06, 0.9)
mouse_filter = 2
visible = false

[connection signal="pressed" from="SafeArea/BaitDock/BaitButton" to="." method="_on_bait_pressed"]
[connection signal="pressed" from="SafeArea/BaitDock/DepthButton" to="." method="_on_depth_pressed"]
'''
s=re.sub(r'load_steps=\d+',f'load_steps={len(re.findall(r"^\[(?:ext_resource|sub_resource) ",s,re.M))+1}',s,count=1)
p.write_text(s,encoding='utf8')
# Match collection styling to the modern HUD; keep the 16-slot discovery grid.
for rel in ['features/collection/collection_panel.tscn','features/collection/collection_row.tscn']:
 p=ROOT/rel
 s=p.read_text(encoding='utf8').replace('res://shared/ui/game_theme.tres','res://assets/ui/modern/hud_theme.tres')
 for a,b in [('panel','panel'),('slot','slot'),('selected','selected'),('button_pressed','pressed'),('button','button')]:
  s=s.replace(f'res://assets/ui/collection/{a}.tres',f'res://assets/ui/modern/{b}.tres')
 s=s.replace('Color(1, 0.92, 0.70, 1)','Color(0.92, 0.97, 1, 1)').replace('Color(1, 0.97, 0.85, 1)','Color(0.7, 1, 0.94, 1)')
 p.write_text(s,encoding='utf8')
p=ROOT/'shared/ui/virtual_joystick.tscn'
s=p.read_text(encoding='utf8').replace('Color(0.02, 0.09, 0.12, 0.52)','Color(0.04, 0.08, 0.12, 0.30)').replace('Color(0.8, 1, 0.94, 0.35)','Color(0.86, 0.95, 1, 0.35)').replace('Color(0.62, 0.96, 0.85, 0.8)','Color(0.78, 0.94, 0.95, 0.55)').replace('border_width_left = 3','border_width_left = 1').replace('border_width_right = 3','border_width_right = 1').replace('border_width_top = 3','border_width_top = 1').replace('border_width_bottom = 3','border_width_bottom = 1')
p.write_text(s,encoding='utf8')
print('Authored modern mobile HUD, vector icons and matching collection skin.')

