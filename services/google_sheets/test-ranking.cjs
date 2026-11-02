const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/Code.gs`, 'utf8'), context);
const record = (player_id, weight_g, time, catch_id, map = 'river') =>
  ({ player_id, weight_g, time, catch_id, map });
const records = [record('a', 500, 1, 'a1'), record('a', 800, 2, 'a2', 'coral_coast'), record('b', 800, 1, 'b1')];
const best = context.chooseBest_(records);
assert.equal(best.length, 2);
assert.equal(best[0].player_id, 'b');
assert.equal(best[1].weight_g, 800);
assert.equal(best[1].map, 'coral_coast');
assert.equal(context.chooseBest_(records.filter(r => r.map === 'river'))[1].weight_g, 500);
assert.equal(context.chooseBest_([]).length, 0);
const ties = context.chooseBest_([record('z', 800, 1, 'z'), record('a', 800, 1, 'b'), record('a', 800, 1, 'a')]);
assert.equal(ties[0].player_id, 'a');
assert.equal(ties[0].catch_id, 'a');
const top = context.chooseBest_(Array.from({length: 120}, (_, i) => record(String(i), i + 1, 1, String(i))));
assert.equal(top.length, 100);
assert.equal(top[0].weight_g, 120);
assert.equal(top[99].weight_g, 21);
assert.equal(top.slice(0, 10).length, 10);
assert.equal(top.slice(0, 50).length, 50);
assert.equal(context.safeCell_('=1+1'), "'=1+1");
assert.equal(context.safeCell_("'literal"), "''literal");
assert.equal(context.safeCell_('  =1+1'), "'  =1+1");
assert.equal(context.safeCell_(800), 800);
assert.equal(context.safeCell_('00000000000000000000000000000001'),"'00000000000000000000000000000001");
assert.equal(context.timeSeconds_(new Date('2026-10-28T00:00:00.123Z')),1793145600.123);
console.log('Passed: global/map best, ties, empty rankings, Top 10/50/100, formula escaping.');

// Run real handlers against counted Sheets/Cache/Properties doubles, without Google data.
const crypto = require('node:crypto');
let reads=0,writes=0,failWrite=false;
class Sheet {
  constructor(name,rows){this.name=name;this.rows=rows;}
  getName(){return this.name;}
  getLastRow(){return this.rows.length;}
  getLastColumn(){return this.rows[0].length;}
  getMaxRows(){return 1000;}
  getRange(row,col,height=1,width=1){return {
    getValues:()=>{reads++;return Array.from({length:height},(_,i)=>Array.from({length:width},(_,j)=>this.rows[row+i-1]?.[col+j-1]??''));},
    setValues:values=>{if(failWrite)throw Error('write failure');writes++;values.forEach((r,i)=>{this.rows[row+i-1]??=[];r.forEach((v,j)=>this.rows[row+i-1][col+j-1]=typeof v==='string'&&v.startsWith("'")?v.slice(1):v);});},
    setValue:value=>{writes++;this.rows[row-1]??=[];this.rows[row-1][col-1]=value;}
  };}
}
const sheets=new Map();
const maps=['river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast'];
const header=Array(9).fill('header');
for(const name of ['Players','Scores','Settings','API_Cache','Rank_All',...maps.map(m=>'Rank_'+m)])sheets.set(name,new Sheet(name,[header.slice()]));
const props=new Map(), memory=new Map();
const api=vm.createContext({
  Utilities:{getUuid:()=>crypto.randomUUID(),DigestAlgorithm:{SHA_256:'sha256'},computeDigest:(_,s)=>crypto.createHash('sha256').update(s).digest(),base64EncodeWebSafe:b=>Buffer.from(b).toString('base64url'),newBlob:s=>({getBytes:()=>Buffer.from(s)})},
  PropertiesService:{getScriptProperties:()=>({getProperty:k=>props.get(k)??null,setProperty:(k,v)=>props.set(k,v),setProperties:o=>Object.entries(o).forEach(([k,v])=>props.set(k,v))})},
  CacheService:{getScriptCache:()=>({get:k=>memory.get(k)??null,put:(k,v)=>memory.set(k,v)})},
  LockService:{getScriptLock:()=>({tryLock:()=>true,releaseLock:()=>{}})},
  SpreadsheetApp:{getActiveSpreadsheet:()=>({getSheetByName:n=>sheets.get(n)}),flush:()=>{}},
  ContentService:{MimeType:{JSON:'json'},createTextOutput:text=>({text,setMimeType(){return this;}})}
});
vm.runInContext(fs.readFileSync(`${__dirname}/Code.gs`,'utf8'),api);
for(let i=0;i<120;i++){
  sheets.get('Players').rows.push(['p'+i,'Angler '+i]);
  sheets.get('Scores').rows.push(['p'+i,'river','fish','catch'+i,'Fish',120000-i*100,'2026-10-28T00:00:00.000Z','']);
}
api.rebuildLeaderboard();
const initialManifest=JSON.parse(props.get('snapshot_manifest'));
assert.equal(Object.keys(initialManifest).length,21);
reads=0;writes=0;api.refreshLeaderboard();
assert.equal(reads,0,'Idle timer must not read Sheets');
assert.equal(writes,0,'Idle timer must not write Sheets');
const request=p=>JSON.parse(api.doGet({parameter:{format:'full',...p}}).text);
reads=0;
const full=request({scope:'all',limit:'100'});
assert.equal(full.rows.length,100);
assert.equal(reads,0,'Warm full response must not read Sheets');
const compact=request({scope:'all',limit:'100',format:'compact'});
assert.equal(compact.rows.length,100);
assert.equal(reads,0,'Compact response should reuse warm full cache');
const fullBytes=Buffer.byteLength(JSON.stringify(full)),compactBytes=Buffer.byteLength(JSON.stringify(compact));
assert.ok(compactBytes<fullBytes*0.6);
memory.clear();reads=0;
assert.equal(request({scope:'all',limit:'10',format:'compact'}).rows.length,10);
assert.equal(reads,1,'Cold request reads exactly one durable row');
reads=0;
const unchanged=request({scope:'all',limit:'10',version:initialManifest['all:10'].version});
assert.equal(unchanged.not_modified,true);
assert.equal(reads,0,'Version check must not read Sheets');
assert.equal(request({limit:'11'}).error,'invalid_query');
assert.equal(request({scope:'bad'}).error,'invalid_query');
// Improve a player outside Top 100 without changing any visible rankings.
sheets.get('Scores').rows[120][5]+=1;
api.markLeaderboardDirty_();reads=0;writes=0;api.refreshLeaderboard();
assert.equal(writes,1,'Invisible score change writes only Settings, no ranking/cache rows');
assert.equal(JSON.parse(props.get('snapshot_manifest'))['all:10'].version,initialManifest['all:10'].version);
// A lower Top 100 change must leave Top 10 and Top 50 versions stable.
sheets.get('Scores').rows[100][5]+=1;
api.markLeaderboardDirty_();api.refreshLeaderboard();
const changed=JSON.parse(props.get('snapshot_manifest'));
assert.equal(changed['all:10'].version,initialManifest['all:10'].version);
assert.equal(changed['all:50'].version,initialManifest['all:50'].version);
assert.notEqual(changed['all:100'].version,initialManifest['all:100'].version);
assert.equal(changed['coral_coast:100'].version,initialManifest['coral_coast:100'].version);
// Durable write failure cannot publish an incomplete snapshot.
const beforeFailure=props.get('snapshot_manifest');
sheets.get('Scores').rows[1][5]+=1;api.markLeaderboardDirty_();failWrite=true;
assert.throws(()=>api.refreshLeaderboard(),/write failure/);
assert.equal(props.get('snapshot_manifest'),beforeFailure);
failWrite=false;api.refreshLeaderboard();
for(let n=0;n<8;n++){sheets.get('Scores').rows[1][5]+=1;api.markLeaderboardDirty_();api.refreshLeaderboard();}
assert.ok(sheets.get('API_Cache').getLastRow()<=43,'Durable cache size must remain bounded');
memory.clear();assert.equal(request({scope:'all',limit:'100'}).rows[0].player_id,'p0');
console.log(JSON.stringify({full_top100_bytes:fullBytes,compact_top100_bytes:compactBytes,reduction_percent:Math.round((1-compactBytes/fullBytes)*100),not_modified_bytes:Buffer.byteLength(JSON.stringify(unchanged)),warm_sheet_reads:0,cold_sheet_reads:1,idle_sheet_reads:0,max_cache_rows:43}));
console.log('Passed: handler cache eviction, stable per-view versions, dirty refresh, failed publication, bounded snapshots.');
const upload={player_id:'a'.repeat(32),token:'b'.repeat(64),player_name:'Test Angler',catches:[{map:'river',species:'tilapia',catch_id:'first',name:'Tilapia',weight_g:2500,time:1793145600}]};
const post=p=>JSON.parse(api.doPost({postData:{contents:JSON.stringify(p)}}).text);
for(const bad of [null,[],true,42,'text', {...upload,player_id:[upload.player_id]}, {...upload,token:[upload.token]}]) {
  assert.equal(post(bad).error,'invalid_payload','Reject coercible identity fields before accessing Sheets');
}
for(const query of [null,false,[],42,'all',{scope:'all',limit:10,version:'x'.repeat(129)}]) {
  assert.equal(post({...upload,query}).error,'invalid_query');
}
assert.equal(post({...upload,catches:[{...upload.catches[0],catch_id:'tab\tformula'}]}).error,'invalid_catch');
assert.equal(post(upload).ok,true);
writes=0;
assert.equal(post(upload).ok,true);
assert.equal(writes,0,'Identical retry must not write sheets or mark dirty');
assert.equal(post({...upload,catches:[{...upload.catches[0],catch_id:'smaller',weight_g:1000}]}).ok,true);
assert.equal(writes,0,'Worse scores must not write');
assert.equal(post({...upload,token:'c'.repeat(64)}).error,'invalid_credentials');
assert.equal(post({...upload,catches:[{...upload.catches[0],weight_g:3000}]}).error,'conflicting_catch');
assert.equal(post({...upload,catches:[{...upload.catches[0],weight_g:-1}]}).error,'invalid_catch');
assert.equal(post({...upload,catches:[{...upload.catches[0],catch_id:'newbest',weight_g:3000}]}).ok,true);
assert.equal(post({...upload,player_name:'New Name',catches:[]}).ok,true);
const fractional={...upload,catches:[{...upload.catches[0],catch_id:'fractional',weight_g:4000,time:1793145600.123456}]};
assert.equal(post(fractional).ok,true);
writes=0;
assert.equal(post(fractional).ok,true,'Fractional timestamps must remain idempotent after Sheets storage');
assert.equal(writes,0);
api.refreshLeaderboard();
const uploadBytes=Buffer.byteLength(JSON.stringify({ok:true}));
console.log('Passed: authenticated delta uploads, duplicate retries, worse-score rejection, name-only updates. Upload acknowledgement: '+uploadBytes+' bytes.');
// Minimal wire contract: no repeated field labels, fish names, timestamps,
// catch IDs, credentials or scope metadata in downloaded ranking rows.
const lean=JSON.parse(api.doGet({parameter:{scope:'all',limit:'100'}}).text);
assert.deepEqual(Object.keys(lean).sort(),['rows','schema','version']);
assert.equal(lean.schema,3);
assert.ok(lean.rows.every(r=>r.length===5));
const leanMap=JSON.parse(api.doGet({parameter:{scope:'river',limit:'100'}}).text);
assert.ok(leanMap.rows.every(r=>r.length===4));
const tupleUpload={player_id:upload.player_id,token:upload.token,catches:[['river','tilapia',5000,1793145600,'tuple-best']]};
assert.equal(post(tupleUpload).ok,true);
writes=0;assert.equal(post(tupleUpload).ok,true);assert.equal(writes,0);
assert.equal(post({...tupleUpload,catches:[['river','unknown_fish',5000,1793145600,'bad']]}).error,'invalid_catch');
assert.equal(post({...tupleUpload,catches:[['river','tilapia',5000,1793145600,'bad','extra']]}).error,'invalid_catch');
api.refreshLeaderboard();
const persisted=sheets.get('Scores').rows.find(r=>r[0]===upload.player_id&&r[1]==='river');
assert.equal(persisted[4],'ปลานิล','Fish name must come from server catalog');
const rankedRows=sheets.get('Rank_All').rows.slice(1).filter(r=>r[0]!==''&&r[0]!==undefined);
const apiRows=request({scope:'all',limit:'100'}).rows;
assert.equal(rankedRows.length,apiRows.length);
rankedRows.forEach((r,i)=>{
  assert.equal(r[0],i+1);
  assert.equal(r[1],apiRows[i].player_id);
  assert.equal(r[6],Math.round(apiRows[i].weight*1000));
  if(i)assert.ok(rankedRows[i-1][6]>=r[6]);
});
assert.equal(new Set(rankedRows.map(r=>r[1])).size,rankedRows.length);
for(const limit of [10,50])assert.deepEqual(request({scope:'all',limit:String(limit)}).rows.map(r=>r.player_id),apiRows.slice(0,limit).map(r=>r.player_id));
// Reorder source rows and leave a gap: uploads must update the correct physical row.
sheets.get('Scores').rows.splice(1,0,Array(8).fill(''));
const swapped=sheets.get('Scores').rows.splice(4,1)[0];sheets.get('Scores').rows.push(swapped);
assert.equal(post({...tupleUpload,catches:[['river','tilapia',5100,1793145600,'after-reorder']]}).ok,true);
assert.equal(sheets.get('Scores').rows.filter(r=>r[0]===upload.player_id&&r[1]==='river').length,1);
assert.equal(sheets.get('Scores').rows.find(r=>r[0]===upload.player_id&&r[1]==='river')[5],5100);
api.refreshLeaderboard();
const objectUpload={...tupleUpload,catches:[{map:'river',species:'tilapia',weight_g:5000,time:1793145600,catch_id:'tuple-best',name:'ปลานิล'}]};
console.log(JSON.stringify({object_upload_bytes:Buffer.byteLength(JSON.stringify(objectUpload)),tuple_upload_bytes:Buffer.byteLength(JSON.stringify(tupleUpload)),upload_ack_bytes:11,download_schema:3,global_fields_per_row:5,map_fields_per_row:4}));
console.log('Passed: minimal default response, compact uploads, catalog names, sorted sheet/API agreement, Top N prefixes, reordered sources and gaps.');
const boardOpen=post({...tupleUpload,catches:[['coral_coast','tilapia',7000,1793145600,'board-open-best']],query:{scope:'coral_coast',limit:10}});
assert.equal(boardOpen.schema,3);
assert.equal(boardOpen.rows[0][3],7000,'Board-open sync returns the new score immediately, without waiting for the timer');
const nextOpen=post({...tupleUpload,catches:[],query:{scope:'coral_coast',limit:10,version:boardOpen.version}});
assert.equal(nextOpen.not_modified,true);
assert.equal(post({...tupleUpload,catches:[],query:{scope:'invalid',limit:10}}).error,'invalid_query');
console.log('Passed: deferred board-open upload + compare + refreshed ranking in one response; unchanged conditional refresh.');
const normalLocks=api.LockService;
let lockAttempts=0;
api.LockService={getScriptLock:()=>({tryLock:()=>++lockAttempts===1,releaseLock:()=>{}})};
const contended=post({...tupleUpload,catches:[['coral_coast','tilapia',7200,1793145600,'contended-refresh']],query:{scope:'coral_coast',limit:10}});
assert.equal(contended.error,'busy_retry','A busy refresh must not acknowledge a stale ranking after an upload');
api.LockService=normalLocks;
const recovered=post({...tupleUpload,catches:[['coral_coast','tilapia',7200,1793145600,'contended-refresh']],query:{scope:'coral_coast',limit:10}});
assert.equal(recovered.rows[0][3],7200);
console.log('Passed: write/refresh lock contention returns a retry; retry is idempotent and returns the new rank.');
// A warm read must not require PropertiesService, locks or SpreadsheetApp.
request({scope:'coral_coast',limit:'10',format:'compact'});
const propertiesBefore=api.PropertiesService;
api.PropertiesService={getScriptProperties:()=>{throw Error('Properties read on fast path');}};
const fast=request({scope:'coral_coast',limit:'10',format:'compact'});
assert.equal(fast.rows[0][3],7200);
api.PropertiesService=propertiesBefore;
assert.notEqual(vm.runInContext("headKey_('all',10,'compact')",api),vm.runInContext("LB_TEST_CONTEXT={book:{getId:()=> 'qa-isolated'}};headKey_('all',10,'compact')",api));
vm.runInContext('LB_TEST_CONTEXT=null',api);
console.log('Passed: one-cache-read fast path bypasses Properties/Sheets; QA and live head namespaces are isolated.');
const revisionBeforeGuest=props.get('source_revision');
reads=0;writes=0;
const scoreFree=post({player_id:'d'.repeat(32),token:'e'.repeat(64),player_name:'No Score QA',catches:[],query:{scope:'all',limit:10}});
assert.equal(scoreFree.schema,3);
assert.equal(reads,1,'Score-free registration reads only Players, never scans Scores');
assert.equal(writes,1,'Score-free registration writes only its player row');
assert.equal(props.get('source_revision'),revisionBeforeGuest,'An unranked guest must not trigger a ranking rebuild');
console.log('Passed: score-free registration does not dirty or rebuild rankings.');
