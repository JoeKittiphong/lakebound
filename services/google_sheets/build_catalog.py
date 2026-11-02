"""Refresh the server species-name catalog from all game fish resources."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
species = {}
for path in sorted((root / 'data/fish').rglob('*.tres')):
    source = path.read_text(encoding='utf-8-sig')
    fish_id = re.search(r'^id = &"([^"]+)"', source, re.M)
    name = re.search(r'^display_name = "([^"]+)"', source, re.M)
    if fish_id and name:
        species[fish_id[1]] = name[1]
target = Path(__file__).with_name('Code.gs')
source = target.read_text(encoding='utf-8-sig')
match = re.search(r'^const LB_SPECIES = .*;$', source, re.M)
if not match:
    raise RuntimeError('LB_SPECIES declaration missing')
declaration = 'const LB_SPECIES = ' + json.dumps(species, ensure_ascii=False, separators=(',', ':')) + ';'
target.write_text(source[:match.start()] + declaration + source[match.end():], encoding='utf-8')
print(f'Updated {len(species)} species')
