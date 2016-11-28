#!/bin/env python

import subprocess
import argparse
import os
#import requests
import json
import logging

TEST_MAP = {
    'functional': ['sf-functional-1node-allinone'],
    'upgrade': ['sf-upgrade-1node-allinone'],
}


def usage():
    p = argparse.ArgumentParser(
        'Plot test_profiling files from commit history')
    p.add_argument('--limit', type=str, default='1 month ago',
                   help='Git history --since parameter')
    p.add_argument('--db', type=str, default='.profiling.d',
                   help='Storage directory for profiling data')
    p.add_argument('--url', type=str,
                   default='https://softwarefactory-project.io/r/changes')
    p.add_argument("--debug", action="store_const", const=True)
    p.add_argument("--verbose", action="store_const", const=True)
    args = p.parse_args()
    if not os.path.isdir(args.db):
        os.mkdir(args.db)
    return args

args = usage()
# logger configuration
logging.getLogger("requests").setLevel(logging.WARNING)
loglevel = logging.INFO
if args.debug:
    loglevel = logging.DEBUG
logging.basicConfig(format='*** %(levelname)s:\t%(message)s\033[m',
                    level=loglevel)
class ColorLog:
    debug = lambda _, x: logging.debug("\033[93m%s" % x)
    info  = lambda _, x: logging.info( "\033[92m%s" % x)
    error = lambda _, x: logging.error("\033[91m%s" % x)
    warning = lambda _, x: logging.warning("\033[95m%s" % x)
log = ColorLog()



def gerrit_query(path):
    r = requests.get("%s/%s" % (args.url, path))
    return json.loads(r.text[4:])


def get_commits(limit):
    commits = []
    for line in subprocess.Popen(
            ['git', 'log', '--since', limit, '--oneline'],
            stdout=subprocess.PIPE).stdout.readlines():
        commit = line.split()[0]
        if not os.path.isdir("%s/%s" % (args.db, commit)):
            os.mkdir("%s/%s" % (args.db, commit))
        commits.append(line.split()[0])
    return commits


def get_review(commit):
    path = "%s/%s/review-number" % (args.db, commit)
    if os.path.isfile(path):
        return open(path).read()
    log.debug("Looking for the review-number of commit %s" % commit)
    infos = gerrit_query("?q=commit:%s" % commit)
    if len(infos) != 1:
        warning("[E] Multiple change matching commit %s" % commit)
    change_nr = str(infos[0]['_number'])
    open(path, 'w').write(change_nr)
    return change_nr


def get_console_logs(commit, review):
    path = "%s/%s/console-logs" % (args.db, commit)
    if os.path.isfile(path):
        return map(lambda x: x[:-1], open(path).readlines())
    log.debug("Looking for the console-logs of review %s" % review)
    infos = gerrit_query("%s/detail" % review)
    messages = infos['messages']
    messages.reverse()
    for message in messages:
        message = message.get('message', '')
        if 'Verified+' not in message and 'Build succeeded' not in message:
            continue
        logs = []
        for line in message.split('\n'):
            if 'SUCCESS in' not in line:
                continue
            logs.append(line.split()[2])
        open(path, 'w').write('\n'.join(logs))
        return logs
    error("Couldn't find console-logs for review %s" % review)


def get_artifacts_url(commit, review, name, log_url):
    path = "%s/%s/%s-artifacts-url" % (args.db, commit, name)
    if os.path.isfile(path):
        return open(path).read()
    log.debug("Looking for artifacts url for commit %s in %s" % (
        commit, log_url))
    console = requests.get("%s/consoleText" % log_url).text.split('\n')
    for idx in xrange(1, 10):
        url = console[-idx]
        if url.startswith('http') and review in url:
            open(path, "w").write(url[:-1])
            return url
    log.error("[E] Couldn't find artifacts url for commit %s in %s" % (
        commit, log_url))
    open(path, "w").write("")
    return ""


def fetch_profiling_data(commit, name, artifacts_url):
    path = "%s/%s/%s-profiling-data" % (args.db, commit, name)
    if os.path.isfile(path):
        return
    log.debug("Fetching tests_profiling for commit %s test %s (%s)" % (
        commit, name, artifacts_url))
    if artifacts_url[-1] == '/':
        artifacts_url = artifacts_url[:-1]
    url = "%s/artifacts/tests_profiling" % artifacts_url
    data = requests.get(url).text
    if 'Not Found' in data:
        log.error("[E] tests_profiling not found for commit %s in %s" % (
                  commit, url))
        data = ""
    else:
        log.info("=> profiling_data %s: %s" % (name, path))
    open(path, "w").write(data)


def update_db(commits):
    for commit in commits:
        log.info("Processing commit %s" % commit)
        review = get_review(commit)
        logs_urls = get_console_logs(commit, review)
        log.debug("=> review https://softwarefactory-project.io/r/#/c/%s" % review)
        log.debug("=> logs %s" % " ".join(logs_urls))
        if len(logs_urls) == 1:
            # Only 1 test ran, must be a doc change
            continue
        for name, test_names in TEST_MAP.items():
            url = None
            for test_name in test_names:
                for log_url in logs_urls:
                    if '/%s/' % test_name in log_url:
                        url = log_url
                        break
                if url:
                    break
            if not url:
                log.warning("[E] Couldn't find %s test for change %s (%s)" % (
                            name, review, logs_urls))
                continue
            log.info("=> log_urls %s: %s" % (name, log_url))
            artifacts_url = get_artifacts_url(commit, review, name, log_url)
            log.debug("=> artifacts_url %s: %s" % (name, artifacts_url))
            fetch_profiling_data(commit, name, artifacts_url)


def load_profile(commit, name):
    path = "%s/%s/%s-profiling-data" % (args.db, commit, name)
    profile = {}
    if not os.path.isfile(path):
        return profile
    for line in open(path).readlines():
        s = line.split()
        t, name = s[0], s[2]
        if name in profile:
            for idx in xrange(2, 10):
                if "%s-%d" % (name, idx) not in profile:
                    name = "%s-%d" % (name, idx)
                    break
        profile[name] = float(t[:-3])
    return profile


metrics = {
    'functional': [
        'build_image',
        'lxc-start',
        'run_functional_tests',
        'run_bootstraps',
        'run_health_base',
        'run_backup_start',
    ],
    'upgrade': [
        'build_image',
        'lxc-start',
        'run_functional_tests',
        'run_bootstraps',
        'fetch_bootstraps_data-2',
        'run_upgrade',
    ]
}

def load_db(commits):
    db = {'labels': []}
    for test in metrics.keys():
        db[test] = {}
        for metric in metrics[test]:
            db[test][metric] = []

    for commit in commits:
        db['labels'].append(commit)
        for test in metrics.keys():
            profile = load_profile(commit, test)
            for metric in metrics[test]:
                value = profile.get(metric)
                if value is None:
                    if len(db[test][metric]) == 0:
                        value = 0.
                    else:
                        # Missing value, use last one
                        value = db[test][metric][-1]
                db[test][metric].append(value)

    return db

def do_plot(db):
    import matplotlib.pyplot as plt
    import numpy as np
    # expand array to avoid convolve boundary effect
    window_size = 5
    for i in xrange(window_size*2):
        for test in metrics.keys():
            for metric in metrics[test]:
                db[test][metric].append(db[test][metric][-1])

    x = range(len(db['labels']))
    plt.figure(1, figsize=(30, 30))
    plot_nr = 411
    for test in sorted(metrics.keys()):
        for plot_type in ('convolved', 'raw'):
            plt.subplot(plot_nr)
            plt.title('%s %s' % (test, plot_type))
            plt.xticks(x, db['labels'], rotation=70)
            plt.yticks(np.arange(0, 50, 5.0))
            for metric in metrics[test]:
                if plot_type == 'raw':
                    data = db[test][metric]
                else:
                    window = np.ones(int(window_size))/float(window_size)
                    data = np.convolve(db[test][metric], window, 'same')
                plt.plot(x, data[:-window_size*2], label=metric)
            plt.gca().yaxis.grid(True)
            plt.tick_params(labelright=True)
            plt.legend(loc='upper left')
            plt.tight_layout()
            plot_nr += 1

    plt.show()

commits = get_commits(args.limit)
commits.reverse()
update_db(commits)
db = load_db(commits)
do_plot(db)
