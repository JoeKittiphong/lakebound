from pathlib import Path
import subprocess,os,json
root=Path(__file__).resolve().parents[1];out=root/'exports/cleanup-qa';engine=Path('C:/Users/Zylaah/programmer/godot/Godot_v4.7.2-stable_win64.exe')
tests=['regions_integration_test','regions_fishing_test','equipment_catalog_test','collection_test','loading_flow_test','loading_motion_test','loading_jungle_test']
results=[]
for name in tests:
 env=os.environ.copy();env['APPDATA']=str(out/'profiles'/name/'roaming');env['LOCALAPPDATA']=str(out/'profiles'/name/'local');log=out/(name+'.log')
 with log.open('wb') as f:
  try:
   result=subprocess.run([str(engine),'--headless','--path',str(root),'--script','res://tests/'+name+'.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120,creationflags=subprocess.CREATE_NO_WINDOW)
   text=log.read_text(encoding='utf-8',errors='replace');bad=[line for line in text.splitlines() if 'FAIL:' in line or 'SCRIPT ERROR' in line or 'Parse Error' in line]
   ok=result.returncode==0 and not bad
   results.append({'test':name,'exit':result.returncode,'passed':ok,'failures':bad[:8]})
  except subprocess.TimeoutExpired:results.append({'test':name,'passed':False,'timeout':True})
 print(json.dumps(results[-1]),flush=True)
 (out/'regression-results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
