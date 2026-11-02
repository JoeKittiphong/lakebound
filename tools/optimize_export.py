"""Generate reproducible dependency-selected exports from Godot's dependency audit.
Run Godot --headless --script res://tools/audit_export_dependencies.gd first.
Runtime scripts include global classes; catalog data and map definitions are explicit roots.
Authoring tools, tests, docs, unused previews and source libraries are never release roots.
"""
from pathlib import Path
import argparse,json,re
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'exports/cleanup-qa'
EXCLUDE='docs/*,exports/*,tools/*,tests/*,signing/*,.signing/*,server/*,services/*,android/*,fishing-game/*,export_templates/*,feature_profiles/*,script_templates/*,text_editor_themes/*,*.log,*.bak'
def generate():
 deps=json.loads((OUT/'godot-dependencies.json').read_text(encoding='utf-8'))
 roots={p for p in deps if p.endswith('.gd') or p.startswith(('res://data/','res://features/map/maps/'))}
 roots.update(['res://features/loading/loading.tscn','res://shared/branding/icon.png','res://shared/branding/adaptive_foreground.png','res://shared/branding/adaptive_background.png'])
 seen=set();queue=list(roots);missing=set()
 while queue:
  name=queue.pop()
  if name in seen:continue
  file=ROOT/name[6:]
  if not file.is_file():missing.add(name);continue
  seen.add(name)
  following=[d.split('::')[-1] for d in deps.get(name,[]) if d.split('::')[-1].startswith('res://')]
  if file.suffix in {'.gd','.tscn','.tres','.json','.gdshader','.gltf'}:
   text=file.read_text(encoding='utf-8-sig',errors='replace')
   for match in re.findall(r'res://[^\s"\'\)\]\}\,]+',text):
    if '%' in match or '{' in match:continue
    target=ROOT/match[6:]
    if target.is_dir():following.extend('res://'+p.relative_to(ROOT).as_posix() for p in target.rglob('*') if p.is_file() and p.suffix not in {'.import','.uid'})
    elif target.is_file():following.append(match)
  queue.extend(following)
 if missing:raise ValueError('Missing dependency roots: '+str(sorted(missing)))
 resources=sorted(p for p in seen if p in deps)
 report={'roots':sorted(roots),'reachable':sorted(seen),'export_resources':resources,'unreachable':sorted(set(deps)-seen),'missing':sorted(missing)}
 OUT.mkdir(parents=True,exist_ok=True)
 (OUT/'reachability.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
 return resources

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
 resources=generate();config=ROOT/'export_presets.cfg';text=config.read_text(encoding='utf-8')
 files='export_files=PackedStringArray('+', '.join(json.dumps(p) for p in resources)+')'
 blocks=re.split(r'(?=\[preset\.\d+\])',text)
 for i,block in enumerate(blocks):
  if not block.startswith('[preset.'):continue
  # Only preset-level keys are matched; option sections remain unchanged.
  block=re.sub(r'^export_filter=.*$', 'export_filter="resources"',block,flags=re.M)
  block=re.sub(r'^export_files=.*\n?', '',block,flags=re.M)
  block=re.sub(r'^export_filter="resources"$', 'export_filter="resources"\n'+files,block,flags=re.M)
  block=re.sub(r'^include_filter=.*$', 'include_filter="online.cfg,data/regions/*.json,world/pond/models/encyclopedia/*.json,shared/ui/fonts/OFL.txt"',block,flags=re.M)
  block=re.sub(r'^exclude_filter=.*$', 'exclude_filter="'+EXCLUDE+'"',block,flags=re.M)
  blocks[i]=block
 updated=''.join(blocks).rstrip()+'\n'
 if args.apply:config.write_text(updated,encoding='utf-8')
 elif text!=updated:raise SystemExit('Export manifest is stale: rerun audit and --apply')
 print(json.dumps({'export_resources':len(resources),'applied':args.apply}))
if __name__=='__main__':main()
