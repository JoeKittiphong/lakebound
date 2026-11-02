"""Measure Apps Script execution/redirect separately from JSON delivery."""
import argparse
import json
import statistics
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, build_opener, urlopen

class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, url):
        return None

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', required=True)
parser.add_argument('--samples', type=int, default=8)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
opener = build_opener(NoRedirect)
rows = []
for i in range(args.samples):
    start = time.perf_counter()
    try:
        opener.open(args.url + '?scope=all&limit=10', timeout=30)
        raise RuntimeError('Expected Google content redirect')
    except HTTPError as response:
        if response.code != 302:
            raise
        target = response.headers['Location']
        response.close()
    first = time.perf_counter()
    with urlopen(target, timeout=30) as response:
        data = json.load(response)
    end = time.perf_counter()
    rows.append({'apps_script_seconds': round(first-start,3), 'content_seconds':round(end-first,3),
                 'total_seconds':round(end-start,3), 'valid':data.get('schema')==3})
report = {'samples': rows, 'median': {key: statistics.median(r[key] for r in rows)
          for key in ['apps_script_seconds','content_seconds','total_seconds']}}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
