"""Read-only HTTP burst test of a deployed Google Apps Script ranking endpoint.

Reports client concurrency, not the number of concurrently running Google scripts.
Does not register players, upload scores, or expose tokens in query strings.
"""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import html
import math
from pathlib import Path
import re
import ssl
import threading
import time
from urllib.parse import urlencode
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--concurrency', type=int, default=100)
    parser.add_argument('--requests', type=int, default=100)
    parser.add_argument('--timeout', type=float, default=30)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'https://script\.google\.com/macros/s/[A-Za-z0-9_-]+/exec', args.url):
        parser.error('Use the exact deployed HTTPS /exec URL, without query parameters')
    if not 1 <= args.concurrency <= 100 or not args.concurrency <= args.requests <= 1000:
        parser.error('Use concurrency 1..100 and requests concurrency..1000')
    if not 0 < args.timeout <= 60:
        parser.error('Timeout must be in (0, 60] seconds')
    gate = threading.Event()
    # Avoid measuring 200 concurrent certificate-store initializations on one
    # load-generator CPU. Certificate/hostname verification remain enabled.
    tls_context = ssl.create_default_context()
    url = args.url + '?' + urlencode({'scope': 'all', 'limit': 10})

    def request(_):
        gate.wait()
        start = time.monotonic()
        result = {'ok': False, 'bytes': 0}
        try:
            with urlopen(url, timeout=args.timeout, context=tls_context) as response:
                body = response.read(262145)
                result['status'] = response.status
                result['bytes'] = len(body)
                data = json.loads(body)
                result['ok'] = (data.get('schema') == 3 and isinstance(data.get('rows'), list)
                                and len(data['rows']) <= 10)
                if not result['ok']:
                    result['error'] = str(data.get('error', 'invalid_ranking_response'))
        except json.JSONDecodeError:
            result['error'] = 'non_json_response'
            text = body.decode('utf-8', errors='replace')
            title = re.search(r'<title>(.*?)</title>', text, re.I|re.S)
            if title: result['page_title'] = html.unescape(title[1]).strip()[:100]
            result['rate_limit_hint'] = any(word in text.lower() for word in ['too many','simultaneous','quota','exceeded'])
        except Exception as error:
            result['error'] = type(error).__name__
        result['seconds'] = round(time.monotonic() - start, 3)
        return result

    start = time.monotonic()
    with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        futures = [pool.submit(request, i) for i in range(args.requests)]
        gate.set()
        results = [future.result() for future in futures]
    latencies = sorted(r['seconds'] for r in results)
    report = {
        'scenario': 'read-only ranking GET; no automatic retry',
        'client_concurrency': args.concurrency,
        'tls_context': 'shared; certificate and hostname verification enabled',
        'requests': args.requests,
        'successes': sum(r['ok'] for r in results),
        'failures': sum(not r['ok'] for r in results),
        'p50_seconds': latencies[math.ceil(len(latencies) * .50) - 1],
        'p95_seconds': latencies[math.ceil(len(latencies) * .95) - 1],
        'elapsed_seconds': round(time.monotonic() - start, 3),
        'response_bytes': sum(r['bytes'] for r in results),
        'errors': dict(Counter(r['error'] for r in results if 'error' in r)),
        'results': results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'results'}, indent=2))
    return int(report['failures'] > 0)


if __name__ == '__main__':
    raise SystemExit(main())
