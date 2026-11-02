"""Validate the scene-authored Blender cooler used by UI generation tools.

The cooler is now edited directly in Godot, rather than recreated from boxes.
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def author_storage_box():
    for relative in (
        'assets/props/thai_ice_cooler/cooler_body.glb',
        'assets/props/thai_ice_cooler/cooler_lid.glb',
        'features/fishing/ui/storage_box_model.tscn',
        'features/fishing/ui/stored_fish_display.tscn',
    ):
        if not (ROOT / relative).is_file():
            raise FileNotFoundError(relative)
    print('Preserving the authored Blender cooler and 3D fish placement scenes.')

if __name__ == '__main__':
    author_storage_box()
