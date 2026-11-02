// Web App execution uses openById and therefore requires the spreadsheets scope.
// The target spreadsheet ID is saved by setupLeaderboard, never supplied by clients.
const LB_MAPS = ['river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast'];
const LB_RANK_HEADER = ['rank','player_id','player_name','map_id','species_id','fish_name','weight_g','caught_at_utc','snapshot_version'];
// Set only inside the isolated integration-test function; never from a request.
let LB_TEST_CONTEXT = null;
function properties_(){return LB_TEST_CONTEXT?LB_TEST_CONTEXT.properties:PropertiesService.getScriptProperties();}
function setupLeaderboard() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  PropertiesService.getScriptProperties().setProperty('spreadsheet_id',ss.getId());
  ss.getSheets().forEach(s => {
    const cols=s.getLastColumn();
    if (!cols) return;
    s.setFrozenRows(1);
    s.getRange(1,1,1,cols).setFontWeight('bold').setBackground('#163E4A').setFontColor('#FFFFFF');
    s.autoResizeColumns(1,cols);
    for(let c=1;c<=cols;c++) s.setColumnWidth(c,Math.max(110,Math.min(s.getColumnWidth(c),320)));
  });
  const guide=ss.getSheetByName('ReadMe');
  guide.setColumnWidth(1,230); guide.setColumnWidth(2,760);
  guide.getDataRange().setWrap(true);
  ss.getSheetByName('API_Cache').setColumnWidth(8,400);
  rebuildLeaderboard();
  if(!ScriptApp.getProjectTriggers().some(t=>t.getHandlerFunction()==='refreshLeaderboard'))
    ScriptApp.newTrigger('refreshLeaderboard').timeBased().everyMinutes(5).create();
}
function getBook_() {
  if(LB_TEST_CONTEXT)return LB_TEST_CONTEXT.book;
  const id=PropertiesService.getScriptProperties().getProperty('spreadsheet_id');
  return id?SpreadsheetApp.openById(id):SpreadsheetApp.getActiveSpreadsheet();
}
function readRows_(sheet,columns) {
  return sheet.getLastRow()<2?[]:sheet.getRange(2,1,sheet.getLastRow()-1,columns||sheet.getLastColumn()).getValues().filter(r=>String(r[0]).trim());
}
function timeSeconds_(value){return Object.prototype.toString.call(value)==='[object Date]'?value.getTime()/1000:Date.parse(String(value))/1000;}
function compareCatch_(a,b) {
  return b.weight_g-a.weight_g || a.time-b.time || a.player_id.localeCompare(b.player_id) || a.catch_id.localeCompare(b.catch_id);
}
function chooseBest_(rows) {
  const best=new Map();
  rows.forEach(r=>{const old=best.get(r.player_id);if(!old||compareCatch_(r,old)<0)best.set(r.player_id,r);});
  return Array.from(best.values()).sort(compareCatch_).slice(0,100);
}
function sourceHash_(value) {
  return Utilities.base64EncodeWebSafe(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,JSON.stringify(value)));
}
function onEdit(e) {
  if(e && e.range && ['Players','Scores'].includes(e.range.getSheet().getName())) markLeaderboardDirty_();
}
// Call after every successful programmatic score/name write; onEdit only handles human edits.
function markLeaderboardDirty_() {
  properties_().setProperty('source_revision',Utilities.getUuid());
}
function rebuildLeaderboard() { markLeaderboardDirty_(); refreshLeaderboard(); }
function putCache_(key,text,ttl=21600) {
  // Cache is optional and may be evicted early; durable snapshots remain in API_Cache.
  try { if(Utilities.newBlob(text).getBytes().length < 95000) CacheService.getScriptCache().put(key,text,ttl); } catch(error) { /* Durable fallback below. */ }
}
function getCache_(key) {
  try {return CacheService.getScriptCache().get(key);} catch(error) {return null;}
}
function headKey_(scope,limit,format){
  const namespace=LB_TEST_CONTEXT?'qa:'+LB_TEST_CONTEXT.book.getId():'live';
  return 'lb:head:'+namespace+':'+scope+':'+limit+':'+format;
}
function refreshLeaderboard() {
  const lock=LockService.getScriptLock();
  if(!lock.tryLock(1000)) return false;
  try {
    const props=properties_();
    const oldManifest=JSON.parse(props.getProperty('snapshot_manifest')||'{}');
    const revision=props.getProperty('source_revision')||'';
    const lastScan=Number(props.getProperty('last_scan_ms')||0);
    if(Object.keys(oldManifest).length && revision===(props.getProperty('processed_revision')||'') && Date.now()-lastScan<21600000)return true;
    const ss=getBook_();
    const players=readRows_(ss.getSheetByName('Players'),2),scores=readRows_(ss.getSheetByName('Scores'),7);
    const fingerprint=sourceHash_(['wire-v3',players.map(r=>r.slice(0,2)),scores]);
    if(props.getProperty('source_hash')===fingerprint&&Object.keys(oldManifest).length){
      props.setProperties({processed_revision:revision,last_scan_ms:String(Date.now())}); return true;
    }
    const names=new Map(players.map(r=>[String(r[0]),String(r[1])]));
    const rows=scores.map(r=>({player_id:String(r[0]),map:String(r[1]),species:String(r[2]),catch_id:String(r[3]),name:String(r[4]),weight_g:Number(r[5]),time:timeSeconds_(r[6])}));
    rows.forEach(r=>{
      if(!names.has(r.player_id)||!LB_MAPS.includes(r.map)||!r.species||!r.catch_id||!Number.isSafeInteger(r.weight_g)||r.weight_g<=0||!Number.isFinite(r.time))throw new Error('Invalid Scores row for player '+r.player_id);
    });
    const version=Utilities.getUuid(),updated=new Date().toISOString(),cache=[],manifest={...oldManifest},rankWrites=[];
    let index=0;
    ['all',...LB_MAPS].forEach(scope=>{
      const best=chooseBest_(scope==='all'?rows:rows.filter(r=>r.map===scope));
      const sheet=ss.getSheetByName(scope==='all'?'Rank_All':'Rank_'+scope);
      const ranked=best.map((r,i)=>[i+1,r.player_id,names.get(r.player_id),r.map,r.species,r.name,r.weight_g,new Date(r.time*1000).toISOString(),version]);
      let scopeChanged=false;
      [10,50,100].forEach(limit=>{
        const key=scope+':'+limit,previous=oldManifest[key],slot=(index++)+2;
        const resultRows=best.slice(0,limit).map((r,i)=>({rank:i+1,player_id:r.player_id,player_name:names.get(r.player_id),map:r.map,species:r.species,name:r.name,weight:r.weight_g/1000,time:r.time,catch_id:r.catch_id}));
        const digest=sourceHash_(resultRows);
        if(previous&&previous.digest===digest&&previous.schema===3)return;
        scopeChanged=true;
        const viewVersion=digest.slice(0,22);
        const payload=JSON.stringify({version:viewVersion,updated_at:updated,scope:scope==='all'?'all':'map',map:scope==='all'?'':scope,limit,provisional:true,rows:resultRows});
        if(payload.length>45000)throw new Error('Snapshot exceeds cell limit: '+scope+':'+limit);
        const row=previous&&previous.row===slot?slot+21:slot;
        cache.push({row,values:[key,scope==='all'?'all':'map',scope==='all'?'':scope,limit,viewVersion,updated,'READY',payload]});
        manifest[key]={row,version:viewVersion,digest,schema:3};
      });
      if(scopeChanged)rankWrites.push({sheet,ranked});
    });
    const cacheSheet=ss.getSheetByName('API_Cache');
    if(cacheSheet.getMaxRows()<43)cacheSheet.insertRowsAfter(cacheSheet.getMaxRows(),43-cacheSheet.getMaxRows());
    // Fixed double-buffer slots: write only inactive slots before publishing the manifest.
    cache.sort((a,b)=>a.row-b.row);
    for(let i=0;i<cache.length;){
      const start=cache[i].row,block=[cache[i++].values];
      while(i<cache.length&&cache[i].row===start+block.length)block.push(cache[i++].values);
      cacheSheet.getRange(start,1,block.length,8).setValues(block);
    }
    SpreadsheetApp.flush();
    cache.forEach(entry=>putCache_('lb:'+entry.values[4]+':'+entry.values[0]+':full',entry.values[7]));
    rankWrites.forEach(({sheet,ranked})=>{
      const count=Math.max(sheet.getLastRow()-1,ranked.length);
      if(!count)return;
      const values=ranked.map(r=>r.map(safeCell_));
      while(values.length<count)values.push(Array(9).fill(''));
      sheet.getRange(2,1,count,9).setValues(values);
    });
    const settings=ss.getSheetByName('Settings');
    settings.getRange(7,2).setValue(version);
    SpreadsheetApp.flush();
    // Final commit: failed writes leave the previous complete snapshot active.
    props.setProperties({snapshot_manifest:JSON.stringify(manifest),active_version:version,source_hash:fingerprint,processed_revision:revision,last_scan_ms:String(Date.now())});
    // Publish the short-lived read head only after the durable commit. QA heads
    // have their own namespace and can never populate the live leaderboard.
    cache.forEach(entry=>{
      const scope=entry.values[1]==='all'?'all':entry.values[2];
      putCache_(headKey_(scope,entry.values[3],'compact'),compactPayload_(entry.values[7]),30);
    });
    return true;
  } finally {lock.releaseLock();}
}
function safeCell_(value) {
  // Preserve numeric-looking IDs (including leading zeroes) as text in Sheets.
  return typeof value==='string'&&(/^[\s]*[=+@'-]/.test(value)||/^\d+$/.test(value))?"'"+value:value;
}
function doGet(e,fresh=false) {
  const p=(e&&e.parameter)||{},scope=p.scope||'all',limit=Number(p.limit||10);
  if(!['all',...LB_MAPS].includes(scope)||![10,50,100].includes(limit))return json_({error:'invalid_query'});
  if(p.format && !['full','compact'].includes(p.format))return json_({error:'invalid_query'});
  const key=scope+':'+limit,format=p.format||'compact';
  const headKey=headKey_(scope,limit,format);
  if(!fresh){
    const head=getCache_(headKey);
    if(head){
      const cached=JSON.parse(head);
      return p.version===cached.version?json_({version:cached.version,not_modified:true}):textJson_(head);
    }
  }
  const props=properties_();
  let entry=JSON.parse(props.getProperty('snapshot_manifest')||'{}')[key];
  if(!entry)return json_({error:'snapshot_not_ready'});
  if(p.version===entry.version)return json_({version:entry.version,not_modified:true});
  let cacheKey='lb:'+entry.version+':'+key+':'+format;
  let payload=getCache_(cacheKey);
  if(payload){putCache_(headKey,payload,30);return textJson_(payload);}
  const lock=LockService.getScriptLock();
  if(!lock.tryLock(5000))return json_({error:'busy_retry'});
  try {
    entry=JSON.parse(props.getProperty('snapshot_manifest')||'{}')[key];
    if(!entry)return json_({error:'snapshot_not_ready'});
    if(p.version===entry.version)return json_({version:entry.version,not_modified:true});
    cacheKey='lb:'+entry.version+':'+key+':'+format;
    payload=getCache_(cacheKey);
    if(!payload){
      const fullKey='lb:'+entry.version+':'+key+':full';
      payload=getCache_(fullKey);
      if(!payload){
        const row=getBook_().getSheetByName('API_Cache').getRange(entry.row,1,1,8).getValues()[0];
        if(row[0]!==key||String(row[4])!==entry.version||row[6]!=='READY')return json_({error:'snapshot_not_ready'});
        payload=String(row[7]);putCache_(fullKey,payload);
      }
      if(format==='compact')payload=compactPayload_(payload);
      putCache_(cacheKey,payload);
    }
    putCache_(headKey,payload,30);
    return textJson_(payload);
  } finally {lock.releaseLock();}
}
function compactPayload_(payload){
  const data=JSON.parse(payload);
  return JSON.stringify({schema:3,version:data.version,
    rows:data.rows.map(r=>data.scope==='all'?[r.player_id,r.player_name,r.map,r.species,Math.round(r.weight*1000)]:[r.player_id,r.player_name,r.species,Math.round(r.weight*1000)])});
}
function textJson_(text){return ContentService.createTextOutput(text).setMimeType(ContentService.MimeType.JSON);}
function json_(data){return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);}

// Read-only smoke check against the actual saved snapshots (no test players).
function smokeLeaderboard() {
  const manifest=JSON.parse(properties_().getProperty('snapshot_manifest')||'{}');
  if(Object.keys(manifest).length!==21)throw new Error('Run setupLeaderboard first');
  let checked=0;
  for(const scope of ['all',...LB_MAPS])for(const limit of [10,50,100]){
    const full=JSON.parse(doGet({parameter:{scope,limit:String(limit),format:'full'}}).getContent());
    if(!Array.isArray(full.rows)||full.rows.length>limit)throw new Error('Invalid snapshot '+scope+':'+limit);
    const same=JSON.parse(doGet({parameter:{scope,limit:String(limit),version:full.version}}).getContent());
    if(!same.not_modified||same.rows!==undefined)throw new Error('Version check failed');
    checked++;
  }
  const compact=JSON.parse(doGet({parameter:{scope:'all',limit:'100',format:'compact'}}).getContent());
  if(compact.schema!==3)throw new Error('Compact response failed');
  console.log('PASS: '+checked+' live snapshots, conditional versions and compact response; no test players written.');
}

// Real Google Sheets integration test in a separate QA workbook. It never writes
// fixture players, tokens or scores into the production leaderboard.
function testLeaderboardIntegration() {
  const book=SpreadsheetApp.create('Lakebound Ranking QA '+new Date().toISOString());
  const local={};
  LB_TEST_CONTEXT={book,properties:{getProperty:k=>local[k]||null,setProperty:(k,v)=>{local[k]=v;},setProperties:o=>Object.assign(local,o)}};
  const check=(ok,message)=>{if(!ok)throw new Error(message);};
  const get=p=>JSON.parse(doGet({parameter:p}).getContent());
  const post=p=>JSON.parse(doPost({postData:{contents:JSON.stringify(p)}}).getContent());
  const token=(Utilities.getUuid().replace(/-/g,'')+Utilities.getUuid().replace(/-/g,''));
  try {
    book.getSheets()[0].setName('Rank_All');
    ['Players','Scores','Settings','API_Cache',...LB_MAPS.map(m=>'Rank_'+m)].forEach(name=>book.insertSheet(name));
    book.getSheetByName('Players').getRange(1,1,1,5).setValues([['player_id','player_name','token_hash','created_at_utc','updated_at_utc']]);
    book.getSheetByName('Scores').getRange(1,1,1,8).setValues([['player_id','map_id','species_id','catch_id','fish_name','weight_g','caught_at_utc','updated_at_utc']]);
    book.getSheetByName('API_Cache').getRange(1,1,1,8).setValues([['cache_key','scope','map_id','limit','snapshot_version','updated_at_utc','status','payload_json']]);
    ['Rank_All',...LB_MAPS.map(m=>'Rank_'+m)].forEach(name=>book.getSheetByName(name).getRange(1,1,1,9).setValues([LB_RANK_HEADER]));
    const players=[],scores=[],now=new Date().toISOString();
    for(let i=0;i<120;i++){
      const id=(i+1).toString(16).padStart(32,'0');
      players.push([id,'QA '+i,sourceHash_(token),now,now]);
      scores.push([id,'river','tilapia','qa-'+i,LB_SPECIES.tilapia,1000+((i*37)%120)*10,'2026-10-28T00:00:00.000Z',now]);
    }
    book.getSheetByName('Players').getRange(2,1,players.length,5).setValues(players.map(r=>r.map(safeCell_)));
    book.getSheetByName('Scores').getRange(2,1,scores.length,8).setValues(scores.map(r=>r.map(safeCell_)));
    rebuildLeaderboard();
    const id=players[0][0],before=get({scope:'river',limit:'10'});
    const upload={player_id:id,token,catches:[['coral_coast','tilapia',9000,1793145600,'qa-crossmap']]};
    const uploadResult=post(upload);
    check(uploadResult.ok,'Upload failed: '+JSON.stringify(uploadResult));
    const scoreCount=book.getSheetByName('Scores').getLastRow();
    check(post(upload).ok&&book.getSheetByName('Scores').getLastRow()===scoreCount,'Duplicate upload created rows');
    check(post({...upload,catches:[['coral_coast','tilapia',8000,1793145600,'qa-smaller']]}).ok,'Lower score retry failed');
    check(post({...upload,token:'0'.repeat(64)}).error==='invalid_credentials','Wrong token accepted');
    check(post({...upload,catches:[['river','tilapia',-1,1793145600,'qa-invalid']]}).error==='invalid_catch','Invalid weight accepted');
    refreshLeaderboard();
    const top100=get({scope:'all',limit:'100'}),top50=get({scope:'all',limit:'50'}),top10=get({scope:'all',limit:'10'});
    check(top100.rows.length===100&&top50.rows.length===50&&top10.rows.length===10,'Top limit failed');
    check(JSON.stringify(top100.rows.slice(0,10))===JSON.stringify(top10.rows),'Top10 is not a Top100 prefix');
    check(JSON.stringify(top100.rows.slice(0,50))===JSON.stringify(top50.rows),'Top50 is not a Top100 prefix');
    check(top100.rows[0][0]===id&&top100.rows[0][2]==='coral_coast'&&top100.rows[0][4]===9000,'Cross-map best failed');
    for(let i=1;i<top100.rows.length;i++)check(top100.rows[i-1][4]>=top100.rows[i][4],'Descending sort failed');
    check(new Set(top100.rows.map(r=>r[0])).size===100,'Duplicate player in global ranking');
    check(get({scope:'river',limit:'10',version:before.version}).not_modified,'Unchanged map version changed');
    check(get({scope:'all',limit:'100',version:top100.version}).not_modified,'Conditional response failed');
    const sheetRows=book.getSheetByName('Rank_All').getRange(2,1,100,9).getValues();
    sheetRows.forEach((r,i)=>check(r[0]===i+1&&r[1]===top100.rows[i][0]&&r[6]===top100.rows[i][4],'Sheet rank/order mismatch'));
    smokeLeaderboard();
    const opened=post({player_id:id,token,catches:[['coral_coast','tilapia',9100,1793145600,'qa-open-sync']],query:{scope:'coral_coast',limit:10}});
    check(opened.schema===3&&opened.rows[0][3]===9100,'Board-open upload did not refresh ranking immediately');
    const reopened=post({player_id:id,token,catches:[],query:{scope:'coral_coast',limit:10,version:opened.version}});
    check(reopened.not_modified,'Board-open conditional response failed');
    console.log('PASS board-open sync: compare upload and return current ranking in one response; next open sends no repeated catches.');
    console.log('PASS real Sheets: upload, duplicate, lower score, authentication, invalid input, global/map best, descending order, unique players, Top10/50/100 prefixes and sheet/API agreement.');
    console.log('QA workbook: '+book.getUrl());
  } finally {console.log('QA workbook retained: '+book.getUrl());LB_TEST_CONTEXT=null;}
}

// Separate score upload from ranking reads. Send only unacknowledged best records,
// in batches of <=100. Keep guest tokens in HTTPS POST bodies, never query strings.
function doPost(e) {
  const body=e&&e.postData&&e.postData.contents;
  if(typeof body!=='string'||body.length>100000)return json_({error:'invalid_payload'});
  let p;
  try {p=JSON.parse(body);} catch(error){return json_({error:'invalid_payload'});}
  if(!p||typeof p!=='object'||Array.isArray(p)||typeof p.player_id!=='string'||typeof p.token!=='string'||!(/^[a-f0-9]{32}$/).test(p.player_id)||!(/^[a-f0-9]{64}$/).test(p.token)||!Array.isArray(p.catches)||p.catches.length>100)return json_({error:'invalid_payload'});
  if(p.query!==undefined&&(!p.query||typeof p.query!=='object'||Array.isArray(p.query)||!['all',...LB_MAPS].includes(p.query.scope)||![10,50,100].includes(p.query.limit)||(p.query.version!==undefined&&(typeof p.query.version!=='string'||p.query.version.length>128))))return json_({error:'invalid_query'});
  if(p.player_name!==undefined&&(typeof p.player_name!=='string'||Array.from(p.player_name.trim()).length<2||Array.from(p.player_name.trim()).length>24||/[\x00-\x1f<>\[\]]/.test(p.player_name)))return json_({error:'invalid_name'});
  const catches=[];
  for(const input of p.catches){
    if(Array.isArray(input)&&input.length!==5)return json_({error:'invalid_catch'});
    const r=Array.isArray(input)?{map:input[0],species:input[1],weight_g:input[2],time:input[3],catch_id:input[4]}:input;
    if(!r||!LB_MAPS.includes(r.map)||typeof r.species!=='string'||!Object.prototype.hasOwnProperty.call(LB_SPECIES,r.species)||typeof r.catch_id!=='string'||!r.catch_id.length||r.catch_id.length>128||/[\x00-\x1f]/.test(r.catch_id)||!Number.isSafeInteger(r.weight_g)||r.weight_g<=0||r.weight_g>1000000000||typeof r.time!=='number'||!Number.isFinite(r.time)||r.time<0||r.time>Date.now()/1000+86400)return json_({error:'invalid_catch'});
    // Sheets ISO dates have millisecond precision; normalize before deduplication.
    catches.push({...r,name:LB_SPECIES[r.species],time:Math.floor(r.time*1000)/1000,player_id:p.player_id});
  }
  const lock=LockService.getScriptLock();
  if(!lock.tryLock(5000))return json_({error:'busy_retry',retry_after:30});
  let rankingChanged=false;
  try {
    const ss=getBook_(),playersSheet=ss.getSheetByName('Players'),scoresSheet=ss.getSheetByName('Scores');
    // Preserve physical row numbers, including gaps left by manual maintenance.
    const players=playersSheet.getLastRow()<2?[]:playersSheet.getRange(2,1,playersSheet.getLastRow()-1,3).getValues();
    const index=players.findIndex(r=>r[0]===p.player_id),digest=sourceHash_(p.token);
    if(index>=0&&players[index][2]!==digest)return json_({error:'invalid_credentials'});
    if(index<0&&p.player_name===undefined)return json_({error:'name_required'});
    const now=new Date().toISOString(),name=p.player_name===undefined?String(players[index][1]):p.player_name.trim();
    const nameChanged=index<0||String(players[index][1])!==name;
    const needScores=catches.length>0||(nameChanged&&index>=0);
    const raw=!needScores||scoresSheet.getLastRow()<2?[]:scoresSheet.getRange(2,1,scoresSheet.getLastRow()-1,7).getValues();
    const buckets=new Map();
    raw.forEach((r,i)=>{if(r[0]===p.player_id)buckets.set(r[1]+':'+r[2],{row:i+2,data:r});});
    const changes=new Map();
    for(const r of catches){
      const key=r.map+':'+r.species,previous=changes.get(key)||buckets.get(key);
      const old=previous&&previous.data;
      if(old&&old[3]===r.catch_id&&(old[5]!==r.weight_g||timeSeconds_(old[6])!==r.time))return json_({error:'conflicting_catch'});
      if(old&&compareCatch_(r,{weight_g:Number(old[5]),time:timeSeconds_(old[6]),player_id:p.player_id,catch_id:String(old[3])})>=0)continue;
      changes.set(key,{row:previous?previous.row:0,data:[p.player_id,r.map,r.species,r.catch_id,r.name,r.weight_g,new Date(r.time*1000).toISOString(),now]});
    }
    rankingChanged=changes.size>0||(nameChanged&&buckets.size>0);
    if(rankingChanged)markLeaderboardDirty_();
    if(nameChanged){
      const created=index<0?now:playersSheet.getRange(index+2,4).getValues()[0][0];
      playersSheet.getRange(index<0?playersSheet.getLastRow()+1:index+2,1,1,5).setValues([[p.player_id,name,digest,created,now].map(safeCell_)]);
    }
    let nextRow=scoresSheet.getLastRow()+1;
    const edits=Array.from(changes.values()).map(c=>({row:c.row||nextRow++,data:c.data.map(safeCell_)})).sort((a,b)=>a.row-b.row);
    for(let i=0;i<edits.length;){
      const start=edits[i].row,block=[edits[i++].data];
      while(i<edits.length&&edits[i].row===start+block.length)block.push(edits[i++].data);
      scoresSheet.getRange(start,1,block.length,8).setValues(block);
    }
    // A board-open request optionally asks for an immediately refreshed snapshot.
    // Leave the write lock before invoking refresh/read handlers below.
  } catch(error){console.error('Score write failed: '+error.message);return json_({error:'write_failed_retry',retry_after:30});}
  finally {lock.releaseLock();}
  if(p.query){
    try {
      // Retries still carry their unacknowledged catches even if the first
      // write committed before its refresh failed. They must finish that refresh.
      const requireFresh=rankingChanged||catches.length>0;
      if(requireFresh&&refreshLeaderboard()===false)return json_({error:'busy_retry',retry_after:3});
      return doGet({parameter:{scope:p.query.scope,limit:String(p.query.limit),version:p.query.version||''}},requireFresh);
    } catch(error){return json_({error:'refresh_failed_retry',retry_after:30});}
  }
  return json_({ok:true});
}
const LB_SPECIES = {"arowana":"ปลามังกรทอง (อโรวาน่าป่า)","betta":"ปลากัด","catfish":"ปลาดุกอุย","alligator_gar":"ปลาอัลลิเกเตอร์การ์","archerfish":"ปลาเสือพ่นน้ำ","asian_redtail_catfish":"ปลากดคัง","asian_swamp_eel":"ปลาไหลนา","barramundi":"ปลากะพงขาว","bigeye_trevally":"ปลากะมงตาโต","bigeye_tuna":"ปลาทูน่าตาโต","bighead_carp":"ปลาซ่งฮื้อ (ปลาหัวโต)","black_ear_catfish":"ปลาเทโพ","black_seabream":"ปลากะพงดำ (ปลาขี้ขม)","black_sharkminnow":"ปลากา (ปลากาดำ)","black_sheatfish":"ปลาเค้าดำ","black_swamp_spiny_eel":"ปลากระทิงดำป่าพรุ","blue_mahseer":"ปลาพลวงหิน","bluefin_tuna":"ปลาทูน่าครีบน้ำเงิน (Bluefin Tuna)","boeseman_croaker":"ปลาม้า","bronze_featherback":"ปลาสลาด","burmese_trout":"ปลาซิวอ้าว","climbing_perch":"ปลาหมอไทย","featherback":"ปลากราย","cobia":"ปลาช่อนทะเล (Cobia)","cobra_snakehead":"ปลาช่อนงูเห่า","coral_trout":"ปลาเก๋าจุดฟ้า (กะรังจุดฟ้า)","crystal_eyed_catfish":"ปลากดแก้ว","diamond_trevally":"ปลาโฉมงาม","dwarf_snakehead":"ปลาก้าง (ก้างพระร่วงภูเขา)","elder_snakehead":"พญาปลาช่อนลายคราม","emperor_snakehead":"ปลาช่อนข้าหลวง","estuary_grouper":"ปลากะรังปากแม่น้ำ (เก๋าปากอ่าว)","fire_eel":"ปลากระทิงไฟ","fourfinger_threadfin":"ปลากุเราสี่เส้น","freshwater_garfish":"ปลากระทั่งเหว","ghost_glass_catfish":"ปลาก้างพระร่วงแก้ว","giant_danio":"ปลาซิวใบไผ่","giant_danionin":"ปลาแปบควาย","freshwater_stingray":"ปลากระเบนน้ำจืด","gourami":"ปลาแรด","giant_grouper":"ปลาเก๋ายักษ์ (กะรังดอกแดง)","giant_luciosoma":"ปลาสะนากยักษ์","giant_mudskipper":"ปลาตีนยักษ์","giant_pangasius":"ปลาเทพา (Chao Phraya Giant Catfish)","giant_snakehead":"ปลาชะโด","giant_trevally":"ปลากะมงพร้าว (GT)","golden_barb":"ปลาตะเพียนทอง","golden_tor":"พญาปลาเวียนทอง (Golden Tor)","goonch":"ปลาแค้ขี้หมู","grass_carp":"ปลาเฉาฮื้อ (ปลากินหญ้า)","great_barracuda":"ปลาสากใหญ่ทะเล","grey_mullet":"ปลากระบอกดำ","hampala":"ปลากระสูบขีด","iridescent_shark":"ปลาสวาย","java_barb":"ปลาตะเพียนขาว","mahi_mahi":"ปลาดอลฟินฟิช (อีโต้มอญ)","malayan_leaffish":"ปลาหมอช้างเหยียบ (หมอโค้ว)","mangrove_snapper":"ปลากะพงแดงป่าชายเลน","marbled_sleeper":"ปลาบู่ทราย","marine_catfish":"ปลากดทะเล","giant_catfish":"ปลาบึก","mountain_barb":"ปลาจาด","mythic_golden_dragon":"พญามังกรทองแห่งป่าลึก","tilapia":"ปลานิล","parrotfish":"ปลานกแก้ว","pearl_gourami":"ปลากระดี่มุก","red_bellied_pacu":"ปลาเปคู (จาระเม็ดน้ำจืด)","red_cheeked_barb":"ปลาแก้มช้ำ","red_fin_titan":"พญาชะโดลายเสือแห่งดงตอ","red_mahseer":"ปลาพลวงชมพู (ปลากือเลาะห์)","red_tilapia":"ปลาทับทิม","river_barracuda":"ปลาสากแม่น้ำ","rohu":"ปลายี่สกเทศ (โรหู่)","royal_featherback":"ปลาตองลาย (กรายเสือ)","sailfish":"ปลากระโทงร่ม (Sailfish)","seven_striped_barb":"ปลายี่สกไทย","siamese_gourami":"ปลาสลิด","tigerfish":"ปลาเสือตอ","silver_arowana":"ปลามังกรเงิน","silver_carp":"ปลาเล่งฮื้อ (ปลาเกล็ดเงิน)","silver_pomfret":"ปลาจาระเม็ดขาว","silver_titan":"พญากะพงขาวปากอ่าว","smallscale_mud_carp":"ปลานวลจันทร์น้ำจืด","snakeskin_gourami":"ปลากระดี่นาง","spanish_mackerel":"ปลาอินทรีบั้ง","spotted_hampala":"ปลากระสูบจุดดง","striped_eel_catfish":"ปลาดุกทะเล (ปลาปิ่นแก้ว)","snakehead":"ปลาช่อน","sultan_fish":"ปลาบ้า (ปลาพวง)","thai_mahseer":"ปลาเวียน (Thai Mahseer)","three_spot_gourami":"ปลากระดี่หม้อ","tinfoil_barb":"ปลากระแห (กระแหทอง)","tire_track_eel":"ปลากระทิงลาย","toli_shad":"ปลาตะลุมพุก","torrent_catfish":"ปลาดุกด่านน้ำตก","wahoo":"ปลาวาฮู (Wahoo)","walking_catfish":"ปลาดุกด้าน","white_sheatfish":"ปลาเค้าขาว","wild_betta":"ปลากัดป่าโบราณ","yellow_mystus":"ปลากดเหลือง","yellowfin_tuna":"ปลาทูน่าครีบเหลือง","freshwater_eel":"ปลาไหล","koi":"ปลาคาร์ปโค่ย","lionhead_goldfish":"ปลาทองหัวสิงห์","redtail_catfish":"ปลากดหางแดง"};
