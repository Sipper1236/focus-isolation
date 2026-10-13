"""Synthetic evaluator unit tests. NEVER macOS acceptance evidence."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('report', Path(__file__).parents[1]/'diagnostic/report.py')
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


def fixture():
    # Synthetic 20 cycles, each 3 seconds away and 1 second active.
    rows=[{'type':'sample','wallMs':t,'monoMs':t-10000,'focused':True,'visibility':'visible'}
          for t in range(10000, 92001, 250)]
    rows[0]['type']='start';rows[-1]['type']='stop'
    rows.insert(-1, {'type':'input:input','wallMs':91750,'monoMs':81750,
                     'focused':True,'visibility':'visible','trusted':True})
    host=[]
    for i in range(20):
        a=11000+i*4000
        host.extend([{'type':'host-inactive','wallMs':a}, {'type':'host-active','wallMs':a+3000}])
    return {'started':10000,'ended':92000,'events':rows},host


class EvaluatorTests(unittest.TestCase):
    def test_complete_synthetic_observations(self):
        p,h=fixture()
        self.assertEqual(report.evaluate(p,h)['result'],'TEST_B_OBSERVATIONS_PASS')

    def reject(self,p,h,needle):
        result=report.evaluate(p,h)
        self.assertNotEqual(result['result'],'TEST_B_OBSERVATIONS_PASS')
        self.assertTrue(any(needle in i for i in result['issues']),result)

    def test_blur_and_recovery_fail(self):
        p,h=fixture();p['events'][10]['type']='blur';p['events'][10]['focused']=False
        self.reject(p,h,'Focus or visibility event')

    def test_hidden_fails_without_event(self):
        p,h=fixture();p['events'][10]['visibility']='hidden'
        self.reject(p,h,'non-visible')

    def test_missing_host_cycles_fail(self):
        p,h=fixture();self.reject(p,h[:38],'Only 19')

    def test_frozen_timer_fails(self):
        p,h=fixture();del p['events'][8:24]
        self.reject(p,h,'Sampling gap')

    def test_fake_input_fails(self):
        p,h=fixture();p['events'][-2]['trusted']=False
        self.reject(p,h,'genuine text input')

    def test_clock_jump_fails(self):
        p,h=fixture();p['events'][40]['wallMs']+=1000
        self.reject(p,h,'wall-clock discontinuity')

    def test_interruption_fails(self):
        for kind in ('host-sleep','vm-failed','vm-stopped','probe-stop'):
            p,h=fixture();h.append({'type':kind,'wallMs':20000})
            self.reject(p,h,'interruption')

    def test_offset_alignment(self):
        p,h=fixture()
        for row in h: row['wallMs']-=5000
        self.assertEqual(report.evaluate(p,h,5000)['result'],'TEST_B_OBSERVATIONS_PASS')
        self.reject(p,h,'Only')

    def test_incomplete_run(self):
        p,h=fixture();p['ended']=None
        self.assertEqual(report.evaluate(p,h)['result'],'INCOMPLETE')

    def test_capacity_stop_fails(self):
        p,h=fixture();p['events'][-1]['reason']='capacity reached'
        self.reject(p,h,'stopped unexpectedly')

    def test_missing_fields(self):
        p,h=fixture();del p['events'][1]['focused']
        self.assertEqual(report.evaluate(p,h)['result'],'INCOMPLETE')


if __name__=='__main__': unittest.main()
