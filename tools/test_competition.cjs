// Isolated Godot test profiles; does not read or overwrite the user's real save.
const {spawnSync}=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),engine=process.env.LAKEBOUND_GODOT||'C:/Users/Zylaah/programmer/godot/Godot_v4.7.2-stable_win64_console.exe';
const suites=process.argv.slice(2);let bad=false;
for(const suite of suites.length?suites:['competition']){
 const dir=path.join(root,'exports','qa-competition',suite);fs.mkdirSync(dir,{recursive:true});
 const env={...process.env,APPDATA:dir,LOCALAPPDATA:dir,LAKEBOUND_BACKGROUND_SYNC:'0',LAKEBOUND_COMPETITION:'0',LAKEBOUND_AUTH:'0',LAKEBOUND_MATCH_EDGE:'0',LAKEBOUND_QA_DIR:dir};
 const args=['--path',root,'--script',`res://tests/${suite}_test.gd`];
 if(!suite.endsWith('visual'))args.unshift('--headless');
 const r=spawnSync(engine,args,{env,encoding:'utf8',windowsHide:true,timeout:120000});
 const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(dir,'run.log'),log);
 console.log(log);if(r.status!==0||/SCRIPT ERROR|Parse Error|FAIL:/.test(log))bad=true;
}
process.exitCode=bad?1:0;
