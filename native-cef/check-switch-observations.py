"""Evaluate actual system-app switches; intentionally not acceptance Test B.

No user input is injected. Keep the standard evaluator's missing-input finding
visible, and make no claim about genuine interaction upon return.
"""
import argparse
import importlib.util
import json
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--negative',action='store_true')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
profile=Path.home()/'Library/Application Support/FocusBrowser'
page=json.loads((profile/'native-host-switch-observations.json').read_text())
assert not page.get('inconclusive'), page
assert page['events'][-1]['reason']=='automatic host-switch probe', page
host_file=max(profile.glob('host-*.jsonl'),key=lambda p:p.stat().st_mtime_ns)
host=[json.loads(line) for line in host_file.read_text().splitlines() if line.strip()]
spec=importlib.util.spec_from_file_location('report',root/'diagnostic/report.py')
report=importlib.util.module_from_spec(spec);spec.loader.exec_module(report)
result=report.evaluate(page,host)
scope='Automatic real macOS foreground switches only. No user input. NOT acceptance Test B.'
output={'scope':scope,'standardEvaluator':result,'negativeControl':args.negative,
        'genuineInputAndCompatibilityTestsRequired':True}
if args.negative:
    assert any(e['focused'] is False for e in page['events']), 'Negative control did not show focus loss.'
    assert any(e['type']=='blur' for e in page['events']), 'Negative control did not record real blur.'
    output['negativeControlDetected']=True
else:
    allowed={'Observer stopped unexpectedly; run incomplete.',
             'No genuine text input recorded after final return.'}
    remaining=[issue for issue in result['issues'] if issue not in allowed]
    assert not remaining, result
    assert result['cycles']>=20, result
    confirmed=sum(e['type']=='switch-away-confirmed' for e in host)
    assert confirmed>=20, host
    output['focusVisibilityObservationsPass']=True
dest=root/'dist';dest.mkdir(exist_ok=True)
prefix='native-negative' if args.negative else 'native-positive'
(dest/(prefix+'-observations.json')).write_text(json.dumps(page,indent=2)+'\n')
(dest/(prefix+'-host.jsonl')).write_text(host_file.read_text())
(dest/(prefix+'-result.json')).write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps(output,indent=2))
