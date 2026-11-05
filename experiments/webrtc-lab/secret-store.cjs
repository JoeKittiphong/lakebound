// Windows DPAPI: permanent TURN credentials are never written as plaintext.
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const file=path.join(__dirname,'.local','cloudflare-turn.dpapi');
function ps(script,input){const r=spawnSync('pwsh.exe',['-NoProfile','-NonInteractive','-Command',script],{input,encoding:'utf8',windowsHide:true});if(r.status!==0)throw Error('credential_store_failed');return r.stdout.trim();}
function save(id,token){if(!/^[a-f0-9]{32}$/.test(id)||!/^[a-zA-Z0-9_-]{32,256}$/.test(token))throw Error('invalid_credentials');const encoded=ps('$rtcText=[Console]::In.ReadToEnd();ConvertFrom-SecureString (ConvertTo-SecureString $rtcText -AsPlainText -Force)',JSON.stringify({id,token}));fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,encoded,{flag:'wx'});}
function load(){if(!fs.existsSync(file))return {};const text=ps('$rtcSecure=ConvertTo-SecureString ([Console]::In.ReadToEnd());[Console]::Out.Write([System.Net.NetworkCredential]::new("",$rtcSecure).Password)',fs.readFileSync(file,'utf8'));const data=JSON.parse(text);return {LAKEBOUND_CF_TURN_KEY_ID:data.id,LAKEBOUND_CF_TURN_API_TOKEN:data.token};}
module.exports={save,load};
