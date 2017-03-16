#/bin/env python

import os
import sys
import yaml
import shutil

path = sys.argv[1]
data = yaml.load(file(path))
if 'projects' in data:
    for name, infos in data['projects'].items():
        for info in infos:
            branch = info.get('branch')
            if branch:
                del info['branch']
                info['branches'] = [branch, ]
if 'templates' in data:
    for template in data['templates']:
        branch = template.get('branch')
        if branch:
            del template['branch']
            template['branches'] = [branch, ]

copy_path = os.path.dirname(path)
name = os.path.basename(path)
shutil.copy(path, copy_path + '/' + name + '_old')
yaml.dump(data, open(path, 'w'), default_flow_style=False)
