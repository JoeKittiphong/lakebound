"""Author editable UI templates and catalog illustrations for the UI refresh."""
from pathlib import Path
import re
import colorsys

ROOT = Path(__file__).resolve().parents[1]

def save(path, content):
    (ROOT / path).write_text(content.strip() + '\n', encoding='utf-8')

save('features/economy/tackle_row.gd', '''
extends PanelContainer
signal buy_requested(id: String)
signal equip_requested(id: String)
var item_id := ""

func _ready() -> void:
 $Content/Actions/Buy.pressed.connect(func(): buy_requested.emit(item_id))
 $Content/Actions/Equip.pressed.connect(func(): equip_requested.emit(item_id))

static func specifications(item: Resource) -> String:
 match item.kind:
  "rod": return "รับแรง %.0f kgf" % item.strength
  "reel": return "จุสาย %.0f ม. · เก็บ %.1f ม./วิ" % [item.length, item.reel_speed]
  "line": return "%.0f kgf · %.0f ม. · %s" % [item.strength, item.length, "เห็นยากในน้ำ" if item.visibility < 0.9 else "เด่นในน้ำ" if item.visibility > 1.1 else "ความใสปานกลาง"]
  "box": return "ความจุ %.0f กก." % item.capacity
  "lure": return {"float": "เหยื่อผิวน้ำ", "swim": "เหยื่อว่ายน้ำ", "sink": "เหยื่อจมน้ำ"}.get(item.motion, "เหยื่อปลอม") + " · ใช้ซ้ำได้"
 return "ใช้ 1 ชิ้นต่อการเหวี่ยง"

func bind(item: Resource, profile: AnglerProfile) -> void:
 item_id = String(item.id)
 $Content/Icon.texture = item.shop_icon
 $Content/Name.text = item.display_name
 $Content/Specs.text = specifications(item)
 tooltip_text = item.description
 var count := int(profile.data.spares.get(item_id, 0)) if item.kind == "line" else profile.quantity(item_id)
 $Content/Count.text = "สำรอง %d ม้วน" % count if item.kind == "line" else "ในกระเป๋า %d ชิ้น" % count
 $Content/Actions/Buy.text = "%d เหรียญ%s" % [item.price, " / %d ชิ้น" % item.quantity if item.quantity > 1 else ""]
 $Content/Actions/Buy.disabled = profile.data.coins < item.price or not profile.data.pending.is_empty() or (item.kind not in ["bait", "lure", "line"] and count > 0)
 var selected := str(profile.data.equipped.get("bait" if item.kind == "lure" else item.kind, "")) == item_id
 $Content/Actions/Equip.text = "ใช้อยู่" if selected and item.kind != "line" else "ใส่สาย" if item.kind == "line" else "เลือกใช้"
 $Content/Actions/Equip.disabled = count <= 0 or not profile.data.pending.is_empty() or (selected and item.kind != "line")
 $Content/Count.modulate = Color(0.62, 0.94, 0.79) if selected else Color(0.7, 0.8, 0.76)
''')

save('features/economy/tackle_row.tscn', '''
[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://features/economy/tackle_row.gd" id="script"]
[ext_resource type="StyleBox" path="res://assets/ui/modern/slot.tres" id="slot"]
[node name="TackleRow" type="PanelContainer"]
custom_minimum_size = Vector2(250, 288)
size_flags_horizontal = 3
script = ExtResource("script")
theme_override_styles/panel = ExtResource("slot")
[node name="Content" type="VBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 5
mouse_filter = 2
[node name="Icon" type="TextureRect" parent="Content"]
custom_minimum_size = Vector2(0, 112)
layout_mode = 2
expand_mode = 1
stretch_mode = 5
mouse_filter = 2
[node name="Name" type="Label" parent="Content"]
layout_mode = 2
text = "คันเบ็ด"
theme_override_font_sizes/font_size = 19
autowrap_mode = 3
mouse_filter = 2
[node name="Specs" type="Label" parent="Content"]
layout_mode = 2
text = "รับแรง 5 kgf"
theme_override_font_sizes/font_size = 15
theme_override_colors/font_color = Color(0.72, 0.82, 0.78, 1)
autowrap_mode = 3
size_flags_vertical = 3
mouse_filter = 2
[node name="Count" type="Label" parent="Content"]
layout_mode = 2
text = "ในกระเป๋า 1 ชิ้น"
theme_override_font_sizes/font_size = 15
mouse_filter = 2
[node name="Actions" type="HBoxContainer" parent="Content"]
layout_mode = 2
theme_override_constants/separation = 6
mouse_filter = 2
[node name="Buy" type="Button" parent="Content/Actions"]
layout_mode = 2
custom_minimum_size = Vector2(0, 48)
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 16
text = "ซื้อ"
[node name="Equip" type="Button" parent="Content/Actions"]
layout_mode = 2
custom_minimum_size = Vector2(82, 48)
theme_override_font_sizes/font_size = 16
text = "เลือกใช้"
''')


# Individual catalog art, saved as ordinary editable SVG assets.
art_dir = ROOT / 'assets/ui/shop'
art_dir.mkdir(exist_ok=True)
for i, resource in enumerate(sorted((ROOT / 'data/equipment').glob('*.tres'))):
    text = resource.read_text(encoding='utf-8')
    kind_match = re.search(r'kind = "(.*?)"', text)
    if not kind_match:
        continue
    kind = kind_match[1]
    rgb = colorsys.hsv_to_rgb((i * 0.137 + 0.08) % 1, 0.43, 0.85)
    color = '#' + ''.join(f'{round(c*255):02x}' for c in rgb)
    common = '<ellipse cx="144" cy="123" rx="88" ry="10" fill="#0b211d" opacity=".5"/>'
    if kind == 'rod':
        body = f'<path d="M43 123L239 19" stroke="#cbd8c5" stroke-width="3"/><path d="M46 121L147 68" stroke="{color}" stroke-width="7"/><path d="M43 123L85 100" stroke="#b79260" stroke-width="13" stroke-linecap="round"/><path d="M49 118L78 103" stroke="#473b32" stroke-width="5"/>'
        body += ''.join(f'<circle cx="{x}" cy="{123-(x-43)*.53:.1f}" r="4" fill="none" stroke="#e6e2c7" stroke-width="1.5"/>' for x in [115,150,182,210,235])
    elif kind == 'reel':
        body = f'<path d="M78 46L193 37L186 53L108 65Z" fill="#c2c6ac"/><path d="M139 50L157 93" stroke="#d7dec7" stroke-width="13"/><ellipse cx="133" cy="89" rx="47" ry="34" fill="{color}" stroke="#dce3cf" stroke-width="5"/><ellipse cx="127" cy="85" rx="25" ry="24" fill="#274940" stroke="#bac9ac" stroke-width="5"/><path d="M166 79L200 66L214 91" fill="none" stroke="#ced2bb" stroke-width="7"/><rect x="203" y="87" width="28" height="13" rx="6" fill="#aa885a"/>'
    elif kind == 'line':
        body = f'<ellipse cx="141" cy="77" rx="53" ry="50" fill="#d2cbb0"/><ellipse cx="141" cy="77" rx="42" ry="39" fill="{color}"/>'
        body += ''.join(f'<ellipse cx="141" cy="77" rx="{r}" ry="{r-3}" fill="none" stroke="#f3e9c5" stroke-width="1" opacity=".5"/>' for r in [23,29,35,40])
        body += '<circle cx="141" cy="77" r="15" fill="#294b41"/><path d="M181 94Q242 128 255 64" fill="none" stroke="#c3e0cf" stroke-width="2"/>'
    elif kind == 'box':
        body = f'<path d="M66 52L191 39L228 60L102 76Z" fill="#dfd4af"/><path d="M66 52L102 76L102 124L66 97Z" fill="#416f62"/><path d="M102 76L228 60L228 109L102 124Z" fill="{color}"/><path d="M145 52L145 33L180 28L180 47" fill="none" stroke="#bfcdb3" stroke-width="7"/><rect x="155" y="77" width="15" height="22" rx="3" fill="#e3d9aa"/>'
    elif kind == 'bait':
        if resource.stem == 'dough':
            body = '<ellipse cx="143" cy="106" rx="69" ry="23" fill="#adba9b"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="20" fill="#d8b975" stroke="#ecd29c" stroke-width="2"/>' for x,y in [(107,89),(148,91),(181,85),(130,60),(168,60)])
        else:
            body = '<ellipse cx="144" cy="100" rx="70" ry="26" fill="#8e7853"/><path d="M84 86C71 32 161 37 148 76S109 111 118 76S191 33 200 84" fill="none" stroke="#da997c" stroke-width="14" stroke-linecap="round"/>'
    else:
        if resource.stem == 'frog':
            body = '<ellipse cx="145" cy="72" rx="45" ry="27" fill="#8dad61"/><circle cx="174" cy="52" r="12" fill="#c7cd72"/><circle cx="176" cy="51" r="5" fill="#1e332c"/><path d="M111 81L78 99L92 110M114 66L78 53L66 69" fill="none" stroke="#89a05a" stroke-width="10" stroke-linecap="round"/>'
        elif resource.stem == 'spinner':
            body = f'<path d="M73 102L204 40" stroke="#dddcb6" stroke-width="4"/><ellipse cx="143" cy="68" rx="19" ry="38" transform="rotate(55 143 68)" fill="{color}" stroke="#f1d899" stroke-width="3"/><circle cx="177" cy="53" r="9" fill="#d8a849"/>'
        elif resource.stem == 'soft_plastic':
            body = f'<path d="M207 65Q168 36 136 73Q103 108 80 77L52 94Q93 131 131 90Q169 55 206 70Z" fill="{color}"/>'
        else:
            body = f'<path d="M74 73Q136 12 219 57Q159 115 74 73Z" fill="{color}" stroke="#ead79d" stroke-width="3"/><path d="M88 73L56 50L58 90Z" fill="#d9b663"/><circle cx="195" cy="54" r="6" fill="#e9e3c5"/><circle cx="196" cy="54" r="3" fill="#1f3731"/>'
        body += '<path d="M142 92L142 112Q151 134 162 110L155 114" fill="none" stroke="#cad3be" stroke-width="3"/>'
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="288" height="148" viewBox="0 0 288 148"><rect width="288" height="148" rx="14" fill="#193d34"/><path d="M0 122Q140 82 288 116V148H0Z" fill="#234b3e"/>{common}{body}</svg>'
    save(f'assets/ui/shop/{resource.stem}.svg', svg)
    if 'id="shop"' not in text:
        text = re.sub(r'load_steps=(\d+)', lambda m: f'load_steps={int(m[1])+1}', text)
        text = text.replace('[resource]', f'[ext_resource type="Texture2D" path="res://assets/ui/shop/{resource.stem}.svg" id="shop"]\n[resource]')
        text += '\nshop_icon = ExtResource("shop")\n'
    resource.write_text(text, encoding='utf-8')

print('Authored shop cards, fish slots and individual catalog SVGs.')

from author_storage_box import author_storage_box
author_storage_box()
