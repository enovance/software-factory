#!/usr/bin/python

import os
import sys
import yaml

db_path = sys.argv[1]


def process_yamls():
    def check_ext(f):
        return f.endswith('.yaml') or f.endswith('.yml')
    yamlfiles = [f for f in os.listdir(db_path) if check_ext(f)]
    for f in yamlfiles:
        yaml_data = yaml.safe_load(
            file(os.path.join(db_path, f)))
        data = yaml_data['resources']
        for rtype, resource in data.items():
            for rid, r in resource.items():
                if 'name' in r:
                    if r['name'] != rid:
                        print ("Resource %s have a name (%s) non consistent"
                               " with rid (%s)" % (rtype, r['name'], rid))

if __name__ == "__main__":
    process_yamls()
