"""Build a reversible legacy Web App proxy, retaining its administrative source."""
import json
import re
from pathlib import Path

here=Path(__file__).parent
backup=here/'.local/legacy-source.gs'
source=(backup if backup.exists() else here.parent/'google_sheets/Code.gs').read_text(encoding='utf-8-sig')
assert len(re.findall(r'function doGet\(',source))==1
assert len(re.findall(r'function doPost\(',source))==1
source=source.replace('function doGet(','function sheetsLegacyGet(').replace('function doPost(','function sheetsLegacyPost(')
config=(here.parents[1]/'online.cfg').read_text()
url=re.search(r'^url="([^"]+)"',config,re.M)[1]
key=re.search(r'^publishable_key="([^"]+)"',config,re.M)[1]
assert key.startswith('sb_publishable_')
source+='\nconst LB_SUPABASE = '+json.dumps({'url':url,'key':key})+';\n'
source+=(here/'legacy_bridge.gs').read_text()
(here/'.local').mkdir(exist_ok=True)
(here/'.local/deploy_bridge.gs').write_text(source,encoding='utf-8')
print('Built legacy compatibility bridge; original source retained in .local/legacy-source.gs')
