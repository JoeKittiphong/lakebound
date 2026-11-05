"""Non-mutating checks of both live routes after activating the migration."""
import json
import re
import urllib.request
from pathlib import Path
from verify_legacy import URL as LEGACY_URL

config=(Path(__file__).parents[2]/'online.cfg').read_text()
url=re.search(r'^url="([^"]+)"',config,re.M)[1]
key=re.search(r'^publishable_key="([^"]+)"',config,re.M)[1]

def send(target,payload,legacy=False):
    body=json.dumps(payload if legacy else {'payload':payload}).encode()
    headers={'Content-Type':'application/json'}
    if not legacy:headers['apikey']=key
    with urllib.request.urlopen(urllib.request.Request(target,data=body,headers=headers),timeout=45) as response:
        return json.load(response)

query={'scope':'all','limit':100}
direct=send(url,{'query':query})
with urllib.request.urlopen(LEGACY_URL+'?scope=all&limit=100',timeout=45) as response:legacy=json.load(response)
assert direct==legacy,'Legacy route must return the same live Supabase snapshot'
print('PASS direct and legacy routes return the same Supabase board')
assert direct.get('rows'),'Expected imported leaderboard rows'
# Existing imported ID with an intentionally wrong token: verifies write gate is
# open and credentials are enforced without changing a real guest or score.
p={'player_id':direct['rows'][0][0],'token':'0'*64,'catches':[]}
for target,is_legacy in [(url,False),(LEGACY_URL,True)]:
    assert send(target,p,is_legacy).get('error')=='invalid_credentials'
    print('PASS '+('legacy' if is_legacy else 'direct')+' POST authenticates imported identity and denies wrong token')
preflight=urllib.request.Request(url,method='OPTIONS',headers={
    'Origin':'https://qa.lakebound.invalid','Access-Control-Request-Method':'POST',
    'Access-Control-Request-Headers':'apikey,content-type'})
with urllib.request.urlopen(preflight,timeout=30) as response:
    assert response.status in (200,204)
    assert response.headers.get('Access-Control-Allow-Origin') in ('*','https://qa.lakebound.invalid')
    allowed=response.headers.get('Access-Control-Allow-Headers','').lower()
    assert 'apikey' in allowed and 'content-type' in allowed
print('PASS web CORS preflight permits JSON RPC with publishable key')
print('CUTOVER RESULT: all checks passed; no player records written')
