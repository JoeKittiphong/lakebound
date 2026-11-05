// Explicitly authorized credential transfer: encrypted local TURN backup ->
// this project's Cloudflare Worker Secrets. No plaintext file or token output.
const path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const stored=require('../experiments/webrtc-lab/secret-store.cjs').load();
const secrets={CF_TURN_KEY_ID:stored.LAKEBOUND_CF_TURN_KEY_ID,CF_TURN_API_TOKEN:stored.LAKEBOUND_CF_TURN_API_TOKEN};
if(Object.values(secrets).some(v=>typeof v!=='string'||!v)){console.error('Encrypted local TURN credentials unavailable');process.exit(1);}
const result=spawnSync(process.execPath,[path.join(root,'services/cloudflare-match/node_modules/wrangler/bin/wrangler.js'),'secret','bulk','--config',path.join(root,'services/cloudflare-match/wrangler.jsonc')],{input:JSON.stringify(secrets),encoding:'utf8',windowsHide:true,timeout:90000,env:{...process.env,CLOUDFLARE_ACCOUNT_ID:'e116e8922d02da5473b371a3d8e93a0c',WRANGLER_SEND_METRICS:'false'}});
let output=(result.stdout||'')+(result.stderr||'');for(const value of Object.values(secrets))output=output.replaceAll(value,'[redacted]');
console.log(output);process.exitCode=result.status??1;
