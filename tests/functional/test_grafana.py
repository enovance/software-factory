import config
import json
import requests

from utils import Base


class TestGrafana(Base):
    """ Functional tests to ensure Grafana show metrics
    """

    def _metric_in_grafana(self, metricname):
        resp = requests.get('http://%s/grafana/api/dashboards/db/zuul' % config.GATEWAY_HOST)
        self.assertTrue(metricname in resp.text)

    def test_zuul_metric_in_grafana(self):
        """ Test if Gnocchi received metrics from Zuul
        """
        self._metric_in_grafana('zuul.pipeline')

    def test_gerrit_metric_in_grafana(self):
        """ Test if Gnocchi received metrics from Gerrit
        """
        self._metric_in_grafana('gerrit.event')
