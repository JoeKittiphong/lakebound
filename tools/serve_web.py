"""Local Web/PWA preview. Use HTTPS hosting for access from a phone."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class WebHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        '.js': 'application/javascript',
        '.wasm': 'application/wasm',
        '.json': 'application/json',
        '.pck': 'application/octet-stream',
    }

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8062)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / 'exports' / 'web'
    if not (root / 'index.html').is_file():
        parser.error('Export the Web preset first.')
    print(f'Lakebound: http://localhost:{args.port}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), partial(WebHandler, directory=str(root))).serve_forever()
