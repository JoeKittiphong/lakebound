// Actual PostgreSQL transactions in a disposable cluster. Never contacts Supabase.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const bin=process.env.PG_BIN||'C:/Program Files/PostgreSQL/18/bin',dir=fs.mkdtempSync(path.join(os.tmpdir(),'lakebound-cloud-'));
const port=String(56000+Math.floor(Math.random()*5000));
function run(exe,args,input){const r=spawnSync(path.join(bin,exe+'.exe'),args,{input,encoding:'utf8',windowsHide:true,timeout:60000,...(exe==='pg_ctl'?{stdio:'ignore'}:{})});if(r.status!==0)throw Error(r.error||r.stderr||r.stdout||'PostgreSQL helper failed');return r.stdout||'';}
function sql(s){return run('psql',['-h','127.0.0.1','-p',port,'-U','postgres','-X','-A','-t','-v','ON_ERROR_STOP=1'],s).trim();}
const q=x=>"'"+JSON.stringify(x).replaceAll("'","''")+"'::jsonb";
const uid=i=>'00000000-0000-4000-8000-'+String(i+1).padStart(12,'0');
const cat=JSON.parse(fs.readFileSync(path.join(__dirname,'../../data/cloud/catalog_v1.json'),'utf8'));
const id=(kind,key)=>cat[kind].indexOf(key),device='0123456789abcdef';
function auth(i,s){return `set role authenticated;set request.jwt.claim.sub='${uid(i)}';set request.jwt.claims='{"app_metadata":{"provider":"google"}}';`+s;}
function rpc(i,p){return JSON.parse(sql(auth(i,`select public.lakebound_sync(${q(p)});`)).split('\n').at(-1));}
let checks=0;function check(ok,label){assert.ok(ok,label);checks++;console.log('PASS '+label);}
try{
 run('initdb',['-D',dir,'-U','postgres','--auth=trust','--encoding=UTF8','--no-locale']);
 run('pg_ctl',['-D',dir,'-l',path.join(dir,'server.log'),'-o',`-p ${port} -h 127.0.0.1`,'-w','start']);
 sql('create role anon;create role authenticated;create role service_role;');sql(fs.readFileSync(path.join(__dirname,'test_platform.sql'),'utf8'));
 for(const file of fs.readdirSync(path.join(__dirname,'migrations')).sort())sql(fs.readFileSync(path.join(__dirname,'migrations',file),'utf8'));
 sql('update lakebound_private.control set writes_enabled=true;');
 for(let i=0;i<2;i++)sql(auth(i,"select public.lakebound_account('{}');"));
 check(rpc(0,{v:2}).error==='cloud_not_enabled','additive rollout starts disabled');
 sql('update lakebound_private.cloud_settings set enabled=true;');
 const base={v:2,c:1,d:device,r:0,t:1700000000000};
 check(rpc(0,base).join(',')==='2,0,0','fresh profile has compact revision and ack');
 const gear=[id('item','light_rod'),id('item','basic_reel'),id('item','nylon'),id('rig','float')];
 const catchRow=[2,id('map','river'),id('fish','tilapia'),1250,123,150,id('item','worm'),1,'fish-001',2,[-1025,2050,-1250,2275,0],'a'.repeat(32)];
 const p={...base,o:[[1,9,1,gear]],f:[catchRow],l:[id('map','river'),'']};
 let r=rpc(0,p);check(Array.isArray(r)&&r[2]===2,'context and catch commit atomically in sequence order');
 check(r[3].h[0][1]===1&&r[3].leader[2][3]===1250,'one catch updates collection stats and leaderboard');
 check(rpc(0,p)[2]===2,'lost acknowledgement retry is idempotent');
 check(sql('select count from lakebound_private.cloud_stats;')==='1','duplicate never increments collection twice');
 check(rpc(0,{...p,f:[catchRow.map((v,i)=>i===3?9999:v)]}).error==='conflicting_event','changed retry fingerprint rejected');
 check(rpc(0,{...base,o:[[4,19,'Skipped']]}).error==='sequence_gap','sequence gaps cannot silently lose events');
 const note={...base,r:r[1],o:[[3,10,'a'.repeat(32),'จุดนี้ปลากินดี']]};
 r=rpc(0,note);check(r[2]===3&&Object.values(r[3].a)[0]==='จุดนี้ปลากินดี','Thai note delta saved');
 const spot=[4,11,'spot-1',id('map','river'),100,200,0,'จุดโปรด',2];
 r=rpc(0,{...base,o:[spot]});check(r[2]===4&&r[3].s['spot-1'][4]==='จุดโปรด','private favorite spot saved');
 r=rpc(0,{...base,o:[[5,12,'spot-1']]});check(r[2]===5&&Object.keys(r[3].s).length===0,'favorite tombstone cannot revive on retry');
 const worm=id('item','worm'),price=cat.defs.item[worm].price;
 r=rpc(0,{...base,o:[[6,2,worm]]});check(r[2]===6&&r[3].w[0]===350-price,'buy price comes from server catalog');
 const retry=rpc(0,{...base,o:[[6,2,worm]]});check(retry[3].w[0]===350-price,'lost buy response returns canonical wallet without spending twice');
 r=rpc(0,{...base,o:[[7,17,'made-up-receipt']]});check(r[2]===7&&r[3].reject[0][1]==='receipt_not_verified','unverified receipt permanently rejected without minting currency');
 check(rpc(0,{...base,o:[[8,7,id('mission','first_three')]]})[3].reject[0][1]==='reward_not_available','client cannot claim unearned mission reward');
 const cp=rpc(0,{...base,g:[0,-1]});check(cp[3].cp[1]>=1,'immutable restore manifest created');
 const revision=cp[3].cp[0],pages=cp[3].cp[1];let restored=[];
 for(let page=0;page<pages;page++){
  const data=rpc(0,{...base,g:[revision,page]});check(data[3].page[0]===revision,'checkpoint page pins revision '+page);
  check(Buffer.byteLength(JSON.stringify(data))<=16384,'checkpoint page stays below response budget '+page);
  restored.push(...data[3].page[2]);
 }
 check(restored.some(x=>x[0]==='j'&&x[1]==='a'.repeat(32)),'restore retains original catch ID and journal');
 check(restored.some(x=>x[0]==='h'&&x[2][0]===1),'restore retains lifetime collection totals');
 check(!JSON.stringify(rpc(1,{...base,g:[0,-1]})).includes('จุดนี้'),'another Google account cannot access private save');
 check(sql("select has_table_privilege('authenticated','lakebound_private.cloud_state','select');")==='f','direct table access denied');
 check(sql("select has_function_privilege('anon','public.lakebound_sync(jsonb)','execute');")==='f','guest role cannot call cloud save');
 const boat=id('item','lake_skiff');
 check(boat===81&&sql("select lakebound_private.cloud_code('item','lake_skiff');")==='81','boat wire ID is appended without renumbering equipment');
 sql(`update lakebound_private.cloud_state set data=jsonb_set(data,'{w,0}','2000') where auth_id='${uid(0)}';`);
 const boatBuy={...base,o:[[9,2,boat]]};
 r=rpc(0,boatBuy);check(r[3].w[0]===500&&r[3].i[boat]===1,'server-priced boat purchase spends 1500 coins and grants one boat');
 r=rpc(0,boatBuy);check(r[3].w[0]===500&&r[3].i[boat]===1,'boat purchase retry cannot charge or grant twice');
 sql(`update lakebound_private.cloud_state set data=jsonb_set(data,'{w,0}','2000') where auth_id='${uid(0)}';`);
 r=rpc(0,{...base,o:[[10,2,boat]]});check(r[3].reject[0][1]==='already_owned','permanent boat cannot be purchased twice');
 r=rpc(0,{...base,o:[[11,20,boat]]});check(r[3].e.boat===boat,'owned boat equips through existing authority protocol');
 const slots=JSON.parse(sql(`select data->'e' from lakebound_private.cloud_state where auth_id='${uid(0)}';`));slots.boat=0;
 r=rpc(0,{...base,o:[[12,13,slots,id('rig','float')]]});check(r[3].e.boat===0&&sql(`select data#>>'{i,${boat}}' from lakebound_private.cloud_state where auth_id='${uid(0)}';`)==='1','boat slot can be cleared without consuming ownership');
 r=rpc(1,{...base,o:[[1,20,boat]]});check(r[3].reject[0][1]==='not_owned','another account cannot equip an unpurchased boat');
 sql(fs.readFileSync(path.join(__dirname,'migrations/202611040018_owned_boats.sql'),'utf8'));
 check(sql("select jsonb_array_length(data->'item') from lakebound_private.cloud_catalog where version=1;")===String(cat.item.length),'boat catalog migration is idempotent');
 console.log(`CLOUD DATABASE RESULT: ${checks} checks passed`);
}finally{try{run('pg_ctl',['-D',dir,'-m','immediate','-w','stop']);}catch{}console.log('Disposable cluster stopped: '+dir);}
