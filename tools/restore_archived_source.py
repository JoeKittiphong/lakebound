"""Restore archived authoring sources without overwriting current work."""
from pathlib import Path
import argparse,json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--restore',action='store_true',help='Without this flag only list missing archived sources');a=p.parse_args()
 index=ROOT/'docs/cleanup-source-archive.json';items=json.loads(index.read_text(encoding='utf-8'))
 for item in items:
  target=(ROOT/item['original']).resolve();source=(ROOT.parent/item['workspace_archive']).resolve()
  if not target.is_relative_to(ROOT):raise ValueError('Target outside project')
  if target.exists():continue
  print(('RESTORE ' if a.restore else 'ARCHIVED ')+item['original'])
  if a.restore:
   if hashlib.sha256(source.read_bytes()).hexdigest()!=item['sha256']:raise ValueError('Archive checksum mismatch')
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
if __name__=='__main__':main()
