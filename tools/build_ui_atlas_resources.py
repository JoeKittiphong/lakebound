"""Build region-only Godot resources from the reviewed generated UI atlas.

Does not render or copy individual sprites: every resource shares one PNG.
Re-run after reviewing/updating atlas_manifest.json for a replacement image.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "assets/ui/atlas"


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def style(name: str, sprite: str, margin: int = 16, content=(12, 10), tint=None):
    manifest = json.loads((ATLAS / "atlas_manifest.json").read_text(encoding="utf-8"))
    box = manifest["regions"][sprite]
    scale = manifest.get("import_size", manifest["size"][0]) / manifest["size"][0]
    x, y, w, h = [round(v * scale) for v in box]
    # Thin data bars sample the opaque flat centre, not rounded sprite edges.
    # Otherwise source corners can swallow a progress bar only eight px tall.
    if name in ("track", "fill"):
        x, y, w, h = x + 20, y + 20, w - 40, h - 40
        margin = 0
    text = f'''[gd_resource type="StyleBoxTexture" load_steps=2 format=3]
[ext_resource type="Texture2D" path="res://assets/ui/atlas/modern_flat.png" id="texture"]
[resource]
texture = ExtResource("texture")
region_rect = Rect2({x}, {y}, {w}, {h})
'''
    for side in ("left", "top", "right", "bottom"):
        text += f"texture_margin_{side} = {margin}.0\n"
        text += f"content_margin_{side} = {content[0 if side in ('left', 'right') else 1]}.0\n"
    if tint:
        text += f"modulate_color = Color({tint})\n"
    write(ATLAS / f"style_{name}.tres", text)


def theme(path: Path, primary: bool, uid: str):
    refs = {"normal": "accent" if primary else "button", "hover": "accent" if primary else "hover",
            "pressed": "hover" if primary else "accent", "disabled": "disabled", "panel": "panel",
            "inset": "inset", "track": "track", "fill": "fill", "grabber": "grabber"}
    text = f'[gd_resource type="Theme" format=3 uid="{uid}"]\n'
    text += '[ext_resource type="FontFile" path="res://shared/ui/fonts/noto_sans_thai.ttf" id="font"]\n'
    for key, value in refs.items():
        text += f'[ext_resource type="StyleBox" path="res://assets/ui/atlas/style_{value}.tres" id="{key}"]\n'
    text += '\n[resource]\ndefault_font = ExtResource("font")\n'
    text += f'default_font_size = {20 if primary else 18}\n'
    navy, ivory = "Color(0.045, 0.12, 0.16, 1)", "Color(0.95, 0.98, 0.97, 1)"
    for key in ("font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"):
        text += f'Button/colors/{key} = {navy if primary else ivory}\n'
    for key in ("font_pressed_color", "font_hover_pressed_color", "icon_pressed_color"):
        text += f'Button/colors/{key} = {ivory if primary else navy}\n'
    text += 'Button/colors/font_disabled_color = Color(0.67, 0.73, 0.76, 1)\n'
    text += 'Button/colors/icon_disabled_color = Color(0.6, 0.68, 0.7, 1)\n'
    text += f'Button/font_sizes/font_size = {24 if primary else 18}\n'
    for state in ("normal", "hover", "pressed", "disabled", "focus"):
        text += f'Button/styles/{state} = ExtResource("{state if state != "focus" else "hover"}")\n'
    for control in ("Panel", "PanelContainer"):
        text += f'{control}/styles/panel = ExtResource("panel")\n'
    for prop, resource in (("background", "track"), ("fill", "fill")):
        text += f'ProgressBar/styles/{prop} = ExtResource("{resource}")\n'
    for control in ("TabBar", "TabContainer"):
        for state, resource in (("tab_selected", "pressed" if not primary else "normal"), ("tab_unselected", "inset"), ("tab_hovered", "hover"), ("tab_disabled", "disabled")):
            text += f'{control}/styles/{state} = ExtResource("{resource}")\n'
        text += f'{control}/colors/font_selected_color = {navy}\n'
        text += f'{control}/colors/font_unselected_color = {ivory}\n'
        text += f'{control}/colors/font_hovered_color = {ivory}\n'
    text += 'TabContainer/styles/panel = ExtResource("inset")\n'
    for control in ("VScrollBar", "HScrollBar"):
        text += f'{control}/styles/scroll = ExtResource("track")\n'
        for state in ("grabber", "grabber_highlight", "grabber_pressed"):
            text += f'{control}/styles/{state} = ExtResource("grabber")\n'
    for state, resource in (("normal", "normal"), ("hover", "hover"), ("pressed", "pressed"), ("disabled", "disabled"), ("focus", "hover")):
        text += f'OptionButton/styles/{state} = ExtResource("{resource}")\n'
    text += f'OptionButton/colors/font_color = {ivory}\nOptionButton/colors/font_pressed_color = {navy}\n'
    text += 'PopupMenu/styles/panel = ExtResource("panel")\nPopupMenu/styles/hover = ExtResource("hover")\n'
    text += 'HSlider/styles/slider = ExtResource("track")\nHSlider/styles/grabber_area = ExtResource("fill")\n'
    write(path, text)


def main():
    manifest = json.loads((ATLAS / "atlas_manifest.json").read_text(encoding="utf-8"))
    scale = manifest.get("import_size", manifest["size"][0]) / manifest["size"][0]
    for name, box in manifest["regions"].items():
        x, y, w, h = [round(v * scale) for v in box]
        write(ATLAS / f"{name}.tres", f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]
[ext_resource type="Texture2D" path="res://assets/ui/atlas/modern_flat.png" id="atlas"]
[resource]
atlas = ExtResource("atlas")
region = Rect2({x}, {y}, {w}, {h})
filter_clip = true
''')
    for name, sprite in {"button": "surface_hover", "hover": "surface_hover", "accent": "surface_accent", "disabled": "surface_disabled", "panel": "surface_normal", "inset": "surface_normal"}.items():
        tint = "0.8, 0.85, 0.9, 1" if name == "inset" else ("0.75, 0.8, 0.85, 1" if name == "button" else None)
        style(name, sprite, tint=tint)
    style("track", "surface_hover", content=(0, 0), tint="0.65, 0.7, 0.75, 1")
    style("fill", "surface_accent", content=(0, 0))
    style("grabber", "surface_hover", content=(5, 5))
    style("joystick_base", "circle_light", margin=0, content=(0, 0), tint="0.14, 0.24, 0.29, 0.55")
    style("joystick_knob", "circle_mint", margin=0, content=(0, 0), tint="1, 1, 1, 0.85")
    # Preserve existing public style paths used by authored scene overrides.
    for name, sprite in {"button": "surface_normal", "pressed": "surface_hover", "accent": "surface_accent", "panel": "surface_panel", "slot": "surface_inset", "selected": "surface_accent"}.items():
        text = (ATLAS / f"style_{dict(pressed='hover', slot='inset', selected='accent').get(name, name)}.tres").read_text(encoding="utf-8")
        write(ROOT / f"assets/ui/modern/{name}.tres", text)
    theme(ROOT / "assets/ui/modern/hud_theme.tres", False, "uid://dhdsjf35401mk")
    theme(ROOT / "shared/ui/game_theme.tres", True, "uid://cj8bp0mxrmqyh")
    print(f"Built {len(manifest['regions'])} shared atlas regions and themes")


if __name__ == "__main__":
    main()
