"""Apply/check imported texture budgets and synchronized AtlasTexture coordinates.

Source PNGs are untouched. Manifest coordinates describe the full-resolution
source; regions are regenerated from them, never repeatedly divided in-place.
Run after regenerating equipment artwork. Godot must reimport after --apply.
"""
from pathlib import Path
import argparse,json,re,sys
ROOT=Path(__file__).resolve().parents[1]
def updates():
 config=json.loads((ROOT/'tools/texture_budget.json').read_text(encoding='utf-8-sig'))
 limits={item['path']:item['limit'] for item in config['textures']}
 edits=[]
 for item in config['textures']:
  path=ROOT/(item['path']+'.import')
  original=path.read_text(encoding='utf-8')
  revised,count=re.subn(r'^process/size_limit=\d+$',f"process/size_limit={item['limit']}",original,flags=re.M)
  if count!=1:raise ValueError(f'Missing/ambiguous size limit: {path}')
  for field,key in (("compression_mode","compress/mode"),("lossy_quality","compress/lossy_quality")):
   if field in item:
    revised,n=re.subn(r'^'+re.escape(key)+r'=[^\n]+$',key+'='+str(item[field]),revised,flags=re.M)
    if n!=1:raise ValueError(f'Missing/ambiguous import setting: {key} in {path}')
  edits.append((path,original,revised))
 for atlas in config['atlases']:
  manifest_path=ROOT/atlas['manifest']; manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
  cell=manifest['cell_size']*limits[atlas['texture']]/atlas['source_width']
  if int(cell)!=cell:raise ValueError('Atlas cell must have integral pixels')
  cell=int(cell)
  original_manifest=manifest_path.read_text(encoding='utf-8')
  manifest['runtime_cell_size']=cell
  manifest['runtime_texture_size']=limits[atlas['texture']]
  manifest['layout_space']='Source coordinates; AtlasTexture regions use runtime_cell_size'
  edits.append((manifest_path,original_manifest,json.dumps(manifest,indent=2,ensure_ascii=False)+'\n'))
  for item in manifest['items']:
   path=manifest_path.parent/(item['id']+'.tres');original=path.read_text(encoding='utf-8')
   rectangle=f"region = Rect2({item['column']*cell}, {item['row']*cell}, {cell}, {cell})"
   revised,count=re.subn(r'^region = Rect2\([^\n]+\)$',rectangle,original,flags=re.M)
   if count!=1:raise ValueError(f'Missing/ambiguous atlas rectangle: {path}')
   edits.append((path,original,revised))
 return edits

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument('--apply',action='store_true');mode.add_argument('--check',action='store_true')
 args=parser.parse_args();edits=updates();changes=[e for e in edits if e[1]!=e[2]]
 for path,_,text in changes:
  if args.apply:path.write_text(text,encoding='utf-8')
  else:print('OUT OF BUDGET:',path.relative_to(ROOT))
 print(f'{len(edits)} texture/atlas settings checked; {len(changes)} '+('updated' if args.apply else 'need updating'))
 return 1 if args.check and changes else 0
if __name__=='__main__':sys.exit(main())
