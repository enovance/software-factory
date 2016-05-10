import config
import json
import requests

from utils import Base


class TestGnocchi(Base):
    """ Functional tests to ensure Gnocchi received and stored metrics
    """

    def _metric_in_gnocchi(self, metricname):
        resp = requests.get('http://%s:8041/v1/metric/' % config.GATEWAY_HOST)
        data = json.loads(resp.text)
        self.assertTrue(len(data) > 0)
        _entry = {}
        for entry in data:
            if metricname in entry.get('name'):
                _entry = entry
                break
        self.assertTrue('id' in _entry)
        _id = _entry['id']
        resp = requests.get('http://%s:8041/v1/metric/%s/measures' % (
                            config.GATEWAY_HOST, _id))
        measures = json.loads(resp.text)
        self.assertTrue(len(measures) > 0)

    def test_zuul_metric_in_gnocchi(self):
        """ Test if Gnocchi received metrics from Zuul
        """
        self._metric_in_gnocchi('zuul')

    def test_gerrit_metric_in_gnocchi(self):
        """ Test if Gnocchi received metrics from Gerrit
        """
        self._metric_in_gnocchi('gerrit')
