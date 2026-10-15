"""Download the pinned ARM64 CEF SDK and verify it before extraction."""
from pathlib import Path
import hashlib
import json
import subprocess

root=Path(__file__).resolve().parent
lock=json.loads((root/'cef.lock.json').read_text())
cache=root/'vendor'
cache.mkdir(exist_ok=True)
archive=cache/lock['archive']
target=cache/lock['directory']
if not archive.exists():
    subprocess.run(['curl','--fail','--location','--retry','3','--output',str(archive)+'.partial',lock['url']],check=True)
    Path(str(archive)+'.partial').replace(archive)
digest=hashlib.sha256()
with archive.open('rb') as stream:
    for block in iter(lambda:stream.read(1024*1024),b''): digest.update(block)
if archive.stat().st_size!=lock['size'] or digest.hexdigest()!=lock['sha256']:
    raise SystemExit('CEF archive checksum mismatch. Do not use this SDK; obtain the pinned archive again.')
if not target.exists():
    subprocess.run(['tar','-xjf',str(archive),'-C',str(cache)],check=True)
if not (target/'include/cef_app.h').exists():
    raise SystemExit('CEF extraction incomplete. Remove only the generated vendor directory and retry.')
print(target)
