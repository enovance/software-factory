#!/usr/bin/python


def set_node_reuse(item, job, params):
    build = item.current_build_set.getBuild(job.name)
    print "zuul_functions: set_node_reuse(", item, job, params, "): ", build
    params['OFFLINE_NODE_WHEN_COMPLETE'] = '0'


def set_node_options(item, job, params):
    build = item.current_build_set.getBuild(job.name)
    print "zuul_functions: set_node_options(", item, job, params, "): ", build
    params['OFFLINE_NODE_WHEN_COMPLETE'] = '1'
