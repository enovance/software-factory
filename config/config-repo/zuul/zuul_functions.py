#!/usr/bin/python


def set_node_options(item, job, params):
    build = item.current_build_set.getBuild(job.name)
    if build:
        # check if job node is master or publish label
        offline_node = True
        for node_label in build.node_labels:
            if node_label == 'master' or node_label.find('publish') != -1:
                offline_node = False
                break
    else:
        # otherwise don't offline the node
        offline_node = False

    if offline_node:
        print "DEBUG: Setting OFFLINE_NODE_WHEN_COMPLETE for job %s" % job.name
        params['OFFLINE_NODE_WHEN_COMPLETE'] = '1'
