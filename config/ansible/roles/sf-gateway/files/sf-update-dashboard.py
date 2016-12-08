#!/bin/env python
# Convert dash file to a json representation for custom dashboard

import sys
import os
import json
import urllib
import urlparse
import subprocess


try:
    inputs = sys.argv[1]
    output = sys.argv[2]
except IndexError:
    print("usage: %s dashboard_dir output_file" % sys.argv[0])
    exit(1)


def load_dashboard(path):
    url = subprocess.Popen(["gerrit-dash-creator", path],
                           stdout=subprocess.PIPE).communicate()[0].strip()
    qs = urlparse.parse_qsl(url)
    data = {
        'gerrit_url': '/r' + url[url.index('/#/dashboard/?'):],
        'title': qs[1][1],
        'tables': [],
    }
    gerrit_query = []
    for table, query in qs[2:]:
        data['tables'].append(table)
        gerrit_query.append(urllib.quote_plus("%s %s" % (query, qs[0][1])))

    data['gerrit_query'] = '/r/changes/?q=%s&O=81' % "&q=".join(gerrit_query)
    return data


dashboards = {}
for dashboard in filter(lambda x: x.endswith(".dash"), os.listdir(inputs)):
    dashboards[dashboard[:-5]] = load_dashboard("%s/%s" % (inputs, dashboard))

open(output, "w").write(json.dumps(dashboards))
