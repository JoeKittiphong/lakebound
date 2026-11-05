// Runs the actual migration and RPC against a disposable local PostgreSQL cluster.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process'), assert=require('node:assert/strict');
const bin=process.env.PG_BIN||'C:/Program Files/PostgreSQL/18/bin';
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'lakebound-pg-'));
const port=String(56000+Math.floor(Math.random()*5000));
function run(exe,args,input){const r=spawnSync(path.join(bin,exe+'.exe'),args,{input,encoding:'utf8',windowsHide:true,timeout:60000});if(r.status!==0)throw Error(r.error||r.stderr||r.stdout);return r.stdout;}
function sql(text){return run('psql',['-h','127.0.0.1','-p',port,'-U','postgres','-d','postgres','-X','-A','-t','-v','ON_ERROR_STOP=1'],text).trim();}
const quote=x=>"'"+JSON.stringify(x).replaceAll("'","''")+"'::jsonb";
// Exercise the original core as owner; the Google gateway is covered by
// test_matches.cjs and is deliberately unavailable to legacy guest clients.
function rpc(p){return JSON.parse(sql('select lakebound_private.lakebound_rankings('+quote(p)+');').split('\n').at(-1));}
let tests=0;function check(ok,label){assert.ok(ok,label);console.log('PASS '+label);tests++;}
try{
 run('initdb',['-D',dir,'-U','postgres','--auth=trust','--encoding=UTF8','--no-locale']);
 run('pg_ctl',['-D',dir,'-l',path.join(dir,'server.log'),'-o',`-p ${port} -h 127.0.0.1`,'-w','start']);
 sql('create role anon; create role authenticated;');
 sql(fs.readFileSync(path.join(__dirname,'test_platform.sql'),'utf8'));
 for(const file of fs.readdirSync(path.join(__dirname,'migrations')).sort()) sql(fs.readFileSync(path.join(__dirname,'migrations',file),'utf8'));
 check(rpc({query:{scope:'all',limit:10}}).rows.length===0,'empty public board');
 const id='0'.repeat(32),token='1'.repeat(64),query={scope:'all',limit:10};
 const p={player_id:id,token,player_name:'นักตกปลา QA',catches:[['river','tilapia',2500,1700000000.125,'qa-1']],query};
 check(rpc(p).error==='migration_in_progress','writes gated before import');
 sql('update lakebound_private.control set writes_enabled=true;');
 let result=rpc(p);check(result.rows[0][4]===2500,'authenticated registration/upload with Thai name');
 const digest=require('node:crypto').createHash('sha256').update(JSON.stringify(token)).digest('base64url')+'=';
 check(sql(`select token_hash from lakebound_private.players where player_id='${id}';`)===digest,'legacy Apps Script token digest compatible');
 check(rpc(p).version===result.version,'duplicate retry idempotent');
 check(rpc({...p,token:'2'.repeat(64)}).error==='invalid_credentials','wrong guest token denied');
 check(rpc({...p,catches:[['river','tilapia',2600,1700000000.125,'qa-1']]}).error==='conflicting_catch','same catch cannot change weight');
 check(rpc({...p,catches:[['river','tilapia',2400,1700000001,'lower']]}).version===result.version,'worse score cannot replace best');
 check(rpc({query:{...query,version:result.version}}).not_modified===true,'conditional version returns not modified');
 check(rpc({query:{scope:'river',limit:10}}).rows[0].length===4,'compact map rows');
 check(rpc({query:{scope:'unknown',limit:10}}).error==='invalid_query','unknown scope rejected');
 check(rpc({query:{scope:'all',limit:1000000}}).error==='invalid_query','unbounded limit rejected');
 check(rpc({...p,player_name:'Bad<Name'}).error==='invalid_name','unsafe name rejected');
 const invalid=[['river','tilapia',3000,1700000001,'valid-first'],['river','unknown',4000,1700000002,'invalid-second']];
 check(rpc({...p,player_name:'Changed QA',catches:invalid}).error==='invalid_catch','invalid later row rejects batch');
 check(rpc({query}).version===result.version,'failed batch rolls back name and earlier score');
 for(const value of [null,[],{}, {query:null},{query:{scope:'all'}}, {...p,catches:null}, {...p,catches:[null]}, {...p,catches:[['river','tilapia',2.5,0,'fraction']] }])
  check(Boolean(rpc(value).error),'malformed payload fails closed');
 const p2={...p,player_id:'a'.repeat(32),token:'b'.repeat(64),player_name:'Second QA',catches:[['river','tilapia',3500,1700000000,'second'],['coral_coast','yellowfin_tuna',4000,1700000001,'ocean']]};
 check(rpc(p2).rows.length===2,'one global row per player across maps');
 check(rpc({query}).rows[0][4]===4000,'global best sorted descending');
 check(rpc({query:{scope:'river',limit:100}}).rows[0][3]===3500,'map board chooses map best');
 check(sql("select has_table_privilege('anon','lakebound_private.players','select');")==='f','anon cannot read credential table');
 check(sql("select has_table_privilege('authenticated','lakebound_private.scores','insert');")==='f','authenticated cannot bypass RPC');
 check(sql("select has_function_privilege('anon','lakebound_private.board(jsonb)','execute');")==='f','private helper cannot be called by clients');
 console.log(`DATABASE RESULT: ${tests} passed`);
} finally {
 try{run('pg_ctl',['-D',dir,'-m','immediate','-w','stop']);}catch{}
 // Retain temporary data for diagnostics; do not touch any installed DB service.
 console.log('Disposable cluster stopped: '+dir);
}
