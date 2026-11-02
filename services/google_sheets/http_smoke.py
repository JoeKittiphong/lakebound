"""Live API smoke test. Registers one QA guest without adding ranking scores."""
import argparse
import json
import secrets
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
player, token = secrets.token_hex(16), secrets.token_hex(32)
payload = {'player_id': player, 'token': token, 'player_name': 'QA HTTP Test', 'catches': [], 'query': {'scope': 'all', 'limit': 10}}
checks = []

def post(data):
    request = Request(args.url, data=json.dumps(data).encode(), headers={'Content-Type': 'application/json'})
    with urlopen(request, timeout=30) as response:
        return json.load(response)

def check(ok, name):
    checks.append({'test': name, 'passed': bool(ok)})
    if not ok:
        raise RuntimeError(name)

first = post(payload)
check(first.get('schema') == 3 and isinstance(first.get('rows'), list), 'POST registers a guest and returns compact ranking')
again = post({**payload, 'query': {**payload['query'], 'version': first['version']}})
check(again.get('not_modified'), 'repeated POST is idempotent and returns unchanged version')
check(post({**payload, 'token': '0' * 64}).get('error') == 'invalid_credentials', 'wrong guest token rejected')
bad = {**payload, 'catches': [['river', 'tilapia', -1, 1793145600, 'invalid-http-test']]}
check(post(bad).get('error') == 'invalid_catch', 'invalid score rejected without recording it')
for limit in [10, 50, 100]:
    with urlopen(args.url + '?' + urlencode({'scope': 'all', 'limit': limit}), timeout=30) as response:
        data = json.load(response)
    check(data.get('schema') == 3 and isinstance(data.get('rows'), list) and len(data['rows']) <= limit, f'GET Top {limit}')
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'checks': checks, 'ranking_scores_added': 0}, indent=2), encoding='utf-8')
print(json.dumps({'passed': len(checks), 'failures': 0, 'ranking_scores_added': 0}))
