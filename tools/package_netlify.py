"""Package the verified Web build with precompressed engine/pack for Netlify Drop."""
import gzip
import shutil
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'exports' / 'web'
target = root / 'exports' / 'netlify'
target.mkdir(parents=True, exist_ok=True)
for file in source.iterdir():
    if file.is_file():
        shutil.copy2(file, target / file.name)
for name in ('index.wasm', 'index.pck'):
    (target / name).write_bytes(gzip.compress((source / name).read_bytes(), compresslevel=6, mtime=0))
(target / '_headers').write_text('''/*
  X-Content-Type-Options: nosniff
/index.html
  Cache-Control: public, max-age=0, must-revalidate
/index.service.worker.js
  Cache-Control: public, max-age=0, must-revalidate
  Content-Type: application/javascript
/index.manifest.json
  Content-Type: application/manifest+json
/index.js
  Content-Type: application/javascript
/index.audio.worklet.js
  Content-Type: application/javascript
/index.audio.position.worklet.js
  Content-Type: application/javascript
/index.wasm
  Content-Type: application/wasm
  Content-Encoding: gzip
/index.pck
  Content-Type: application/octet-stream
  Content-Encoding: gzip
''', encoding='utf-8')
archive = root / 'exports' / 'lakebound-netlify.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as out:
    for file in target.iterdir():
        if file.is_file():
            out.write(file, file.name)
print(f'{archive}: {archive.stat().st_size:,} bytes')
