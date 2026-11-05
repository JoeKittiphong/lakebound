"""Read-only parity test of all 21 Supabase views against the private XLSX backup."""
import argparse
import concurrent.futures
import json
import re
import statistics
import time
import urllib.request
from pathlib import Path
import openpyxl
from import_sheets import text, timestamp, MAPS

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('backup',type=Path)
    parser.add_argument('--output',type=Path,default=Path(__file__).parent/'.local/live-results.json')
    args=parser.parse_args()
    config=(Path(__file__).parents[2]/'online.cfg').read_text()
    url=re.search(r'^url="([^"]+)"',config,re.M)[1]
    key=re.search(r'^publishable_key="([^"]+)"',config,re.M)[1]
    book=openpyxl.load_workbook(args.backup,read_only=True,data_only=True)
    names={text(r[0]):text(r[1]) for r in list(book['Players'].values)[1:] if r[0]}
    source=[(text(r[0]),text(r[1]),text(r[2]),text(r[3]),int(r[5]),timestamp(r[6])) for r in list(book['Scores'].values)[1:] if r[0]]
    checks=[];latencies=[]
    def request(query):
        body=json.dumps({'payload':{'query':query}}).encode()
        req=urllib.request.Request(url,data=body,headers={'Content-Type':'application/json','apikey':key})
        start=time.monotonic()
        with urllib.request.urlopen(req,timeout=30) as response: result=json.load(response)
        return result,(time.monotonic()-start)*1000
    for scope in ['all']+sorted(MAPS):
        best={}
        order=lambda r:(-r[4],r[5],r[0],r[3],r[1],r[2])
        for row in source:
            if scope!='all' and row[1]!=scope: continue
            if row[0] not in best or order(row)<order(best[row[0]]):best[row[0]]=row
        ranked=sorted(best.values(),key=order)
        for limit in [10,50,100]:
            q={'scope':scope,'limit':limit}
            actual,ms=request(q);latencies.append(ms)
            expected=[[r[0],names[r[0]],r[1],r[2],r[4]] if scope=='all' else [r[0],names[r[0]],r[2],r[4]] for r in ranked[:limit]]
            assert actual.get('schema')==3 and actual.get('rows')==expected,f'{scope}/{limit}: parity mismatch'
            unchanged,_=request(dict(q,version=actual['version']))
            assert unchanged.get('not_modified') is True and 'rows' not in unchanged,'conditional response mismatch'
            checks.append({'scope':scope,'limit':limit,'rows':len(expected),'ms':round(ms,1),'parity':True,'conditional':True})
            print(f'PASS {scope} Top{limit}: {len(expected)} rows, {ms:.0f} ms')
    # Bounded read burst; no registration or production score writes.
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
        burst=list(pool.map(lambda _:request({'scope':'all','limit':100}),range(30)))
    scored_players=len({r[0] for r in source})
    assert all(r.get('schema')==3 and len(r['rows'])==min(100,scored_players) for r,_ in burst)
    report={'checks':checks,'parity_checks':len(checks),'conditional_checks':len(checks),'read_burst_success':len(burst),'read_burst_total':30,
      'serial_median_ms':round(statistics.median(latencies),1),'burst_max_ms':round(max(ms for _,ms in burst),1)}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,indent=2),encoding='utf8')
    print('LIVE RESULT: 21 parity + 21 conditional + 30 concurrent reads passed')
    book.close()

if __name__=='__main__':main()
