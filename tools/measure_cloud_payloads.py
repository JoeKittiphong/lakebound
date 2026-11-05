"""Offline planning benchmark. Synthetic fixtures, no HTTP, real saves or credentials.

Fixtures follow CatchSettlement/ProfileStore fields. Numeric catalog IDs are
illustrative protocol IDs, not a generated production registry. Sizes are UTF-8
JSON bodies only, excluding auth/HTTP/TLS and transport compression.
"""
import argparse
import copy
import json
from pathlib import Path

def size(value):
    return len(json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode('utf-8'))

def build():
    record={
        'species':'tilapia','name':'ปลานิล','weight':1.25,'map':'river','depth':1.5,
        'catch_id':'0123456789abcdef0123456789abcdef',
        'fish_key':'river:fish-001','bait_id':'worm','bait_kind':'bait','boss':False,
        'mission_eligible':True,'bait':'ไส้เดือน','rod':'คันเบา','reel':'รอกพื้นฐาน',
        'line':'ไนลอน','time':1793612000.123,
        'location':{'angler_xz':[-10.25,20.5],'bite_xz':[-12.5,22.75],'from_boat':False}}
    # v2 fields: seq,map,species,grams,dt_ms,depth_cm,bait,loadout_rev,
    # stable_fish_key,flags,optional coordinates in cm (angler xz,bite xz,boat).
    row=[41,1,80,1250,0,150,1,3,'fish-001',0,[-1025,2050,-1250,2275,0]]
    def packet(rows):
        return {'p':{'v':2,'c':1,'r':20,'d':'0123456789abcdef','t':1793612000123,'f':rows}}
    current_tuple=['river','tilapia',1250,1793612000.123,record['catch_id']]
    current={'payload':{'player_id':'0'*32,'token':'1'*64,'player_name':'นักตกปลา',
                        'catches':[current_tuple],'query':{'scope':'river','limit':10}}}
    no_location=copy.deepcopy(row);no_location.pop()
    batch=[]
    verbose=[]
    for i in range(10):
        event=copy.deepcopy(row);event[0]+=i;event[3]+=i;event[4]=i*1000;event[8]=f'fish-{i+1:03}'
        batch.append(event)
        full=copy.deepcopy(record);full['catch_id']=f'{i+1:032x}';full['fish_key']=f'river:fish-{i+1:03}'
        full['time']+=i;full['weight']+=i/1000;verbose.append(full)
    fixtures={
        'Verbose catch record with location':record,
        'Current best-only catch tuple (fewer semantics)':current_tuple,
        'Current guest ranking request (not equivalent to cloud ingest)':current,
        'Proposed catch tuple with location':row,
        'Proposed catch tuple without location':no_location,
        'Proposed single-event RPC body':packet([row]),
        'Ten verbose catch records':verbose,
        'Proposed ten-event RPC body':packet(batch),
        'Proposed version-only check':{'p':{'v':2,'r':20}},
        'Proposed compact acknowledgement':[2,20,50],
        'Proposed unchanged response':[2,20],
        'Proposed buy command':{'p':{'v':2,'r':20,'d':'0123456789abcdef','o':[[41,2,7,1,8]]}},
    }
    rows=[{'case':name,'json_body_bytes':size(value)} for name,value in fixtures.items()]
    return {'measurement':'UTF-8 compact JSON body, no compression or HTTP/auth/TLS',
            'fixture':'synthetic, based on current source fields; not real player data',
            'comparability':'Current ranking sends only best statistics. New ingest includes journal/mission/location context; compare tuple semantics before claiming savings.',
            'results':rows}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'docs/cloud-payload-measurements.json')
    args=parser.parse_args();report=build()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for entry in report['results']:print(f"{entry['json_body_bytes']:5} B  {entry['case']}")
