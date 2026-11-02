"""Verify cleanup artifacts and extract Android game assets for isolated Godot smoke tests."""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import argparse,json,hashlib

def audit(path):
 with ZipFile(path) as z:
  assert z.testzip() is None,'Invalid ZIP CRC'
  entries=z.infolist();names=z.namelist()
  forbidden=[n for n in names if any('/assets/'+part+'/' in '/'+n for part in ['tests','tools','exports','docs','signing','.signing','server','services']) or n.endswith(('.jks','.dpapi','.keystore'))]
  assert not forbidden,'Development/private files in build'
  assert any('ui_symbols.fnt' in n and n.endswith('.fontdata') for n in names),'Symbol font missing'
  native={i.filename:{'bytes':i.file_size,'sha256':hashlib.sha256(z.read(i)).hexdigest()} for i in entries if i.filename.endswith('.so')}
  return {'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'zip_ok':True,'forbidden_count':len(forbidden),'native':native,'game_stored_bytes':sum(i.compress_size for i in entries if '/assets/' in i.filename or i.filename.startswith('assets/')),'files':len(entries)}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['before','after','apk','report','runtime']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();report={label:audit(getattr(a,label)) for label in ['before','after','apk']}
 assert report['before']['native']==report['after']['native'],'AAB ABI support/native engine changed'
 assert all('/arm64-v8a/' in k for k in report['apk']['native']),'Compact APK contains extra ABIs'
 report['saved_bytes']=report['before']['bytes']-report['after']['bytes'];report['saved_percent']=report['saved_bytes']/report['before']['bytes']*100
 with ZipFile(a.after) as archive,ZipFile(a.runtime,'w',compression=ZIP_DEFLATED,compresslevel=1) as runtime:
  for i in archive.infolist():
   prefix=next((s for s in ['assetPackInstallTime/assets/','base/assets/'] if i.filename.startswith(s)),None)
   if prefix:runtime.writestr(i.filename[len(prefix):],archive.read(i))
 a.report.write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps({k:report[k]['bytes'] for k in ['before','after','apk']}));print('Archive integrity, runtime glyphs, excluded files and unchanged AAB CPU support verified')
if __name__=='__main__':main()
