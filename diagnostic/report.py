"""Conservative Test B evaluator. Passing this report is not full acceptance.

Host/guest wall clocks must be aligned before running. Timer gaps invalidate
coverage rather than being treated as evidence of focus preservation.
"""
import argparse
import json
import math
from pathlib import Path


def evaluate(page, host, offset_ms=0):
    issues = []
    events = page.get('events', [])
    start, end = page.get('started'), page.get('ended')
    if not isinstance(start, (int, float)) or not isinstance(end, (int, float)) or end <= start:
        return {'result': 'INCOMPLETE', 'issues': ['Missing completed measurement interval.']}
    required = ('wallMs', 'monoMs', 'focused', 'visibility', 'type')
    if not events or any(any(k not in e for k in required) for e in events):
        return {'result': 'INCOMPLETE', 'issues': ['Malformed or missing observations.']}
    if any(not isinstance(e['wallMs'], (int, float)) or not math.isfinite(e['wallMs'])
           or not isinstance(e['monoMs'], (int, float)) or not math.isfinite(e['monoMs']) for e in events):
        return {'result': 'INCOMPLETE', 'issues': ['Invalid timestamps.']}
    if events[0]['type'] != 'start' or events[-1]['type'] != 'stop':
        issues.append('Missing start/stop observations.')
    if events[-1].get('reason', 'manual') != 'manual':
        issues.append('Observer stopped unexpectedly; run incomplete.')
    if abs(events[0]['wallMs']-start)>500 or abs(events[-1]['wallMs']-end)>500:
        issues.append('Observations do not cover the declared measurement interval.')
    if any(e['type'] in ('host-sleep', 'host-wake', 'vm-failed', 'vm-stopped', 'probe-stop', 'vm-start-failed')
           and start <= e['wallMs']+offset_ms <= end for e in host):
        issues.append('Host sleep or VM/probe interruption during measurement.')
    if any(e['focused'] is not True or e['visibility'] != 'visible' for e in events):
        issues.append('Page was unfocused or non-visible during measurement.')
    if any(e['type'] in ('blur', 'focus', 'visibilitychange') for e in events):
        issues.append('Focus or visibility event occurred during measurement; inspect cause manually.')
    gaps = [b['monoMs']-a['monoMs'] for a,b in zip(events, events[1:])]
    clock_drift = [abs((b['wallMs']-a['wallMs'])-(b['monoMs']-a['monoMs']))
                   for a,b in zip(events, events[1:])]
    if any(g < 0 for g in gaps) or any(d > 250 for d in clock_drift) or any(
            b['wallMs'] < a['wallMs'] for a,b in zip(events, events[1:])):
        issues.append('Non-monotonic observations or wall-clock discontinuity.')
    samples = [e for e in events if e['type'] in ('start', 'sample', 'stop')]
    max_gap = max((b['monoMs']-a['monoMs'] for a,b in zip(samples, samples[1:])), default=0)
    if len(samples) < 3 or max_gap > 1500:
        issues.append('Sampling gap >1500 ms or insufficient samples: lifecycle coverage unproven.')
    intervals, away = [], None
    for e in host:
        t = e['wallMs'] + offset_ms  # page time = host time + measured offset
        if t < start or t > end:
            continue
        if e['type'] == 'host-inactive':
            if away is not None:
                issues.append('Duplicate host deactivation.')
            away = t
        elif e['type'] == 'host-active':
            if away is not None:
                intervals.append((away, t));away = None
    if away is not None:
        issues.append('Measurement ended while host remained inactive.')
    if len(intervals) < 20:
        issues.append(f'Only {len(intervals)} complete host switch cycles; need 20.')
    for i,(a,b) in enumerate(intervals,1):
        inside=[e for e in samples if a <= e['wallMs'] <= b]
        if b-a < 2000 or len(inside) < 3:
            issues.append(f'Cycle {i}: dwell too short or insufficient away samples (use >=3 seconds).')
        if inside and (inside[0]['wallMs']-a>1500 or b-inside[-1]['wallMs']>1500):
            issues.append(f'Cycle {i}: missing interval-edge coverage.')
    returned_input = bool(intervals) and any(e['type']=='input:input' and e.get('trusted') is True
                                            and e['wallMs'] > intervals[-1][1] for e in events)
    if not returned_input:
        issues.append('No genuine text input recorded after final return.')
    return {'result': 'FAIL_OR_INCOMPLETE' if issues else 'TEST_B_OBSERVATIONS_PASS',
            'cycles':len(intervals), 'maxSampleGapMs':max_gap, 'issues':issues,
            'scope':'Only supplied observations; manual A/C/D, clock alignment and real host switching require attestation.'}


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('page', type=Path)
    parser.add_argument('host', type=Path)
    parser.add_argument('--offset-ms', type=float, default=0)
    args=parser.parse_args()
    try:
        result=evaluate(json.loads(args.page.read_text()),
                        [json.loads(line) for line in args.host.read_text().splitlines() if line.strip()],
                        args.offset_ms)
    except (ValueError, KeyError, TypeError) as error:
        result={'result':'INCOMPLETE','issues':[f'Invalid input: {error}']}
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result['result']=='TEST_B_OBSERVATIONS_PASS' else 1)
