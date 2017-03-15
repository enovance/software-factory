#!/usr/bin/python

import yaml
import glob
import os

# Load old configurations
try:
    sfconfig = yaml.safe_load(open("/etc/software-factory/sfconfig.yaml"))
except IOError:
    sfconfig = {'nodepool': {}}
images = yaml.safe_load(open("nodepool/images.yaml"))
labels = yaml.safe_load(open("nodepool/labels.yaml"))

# Prepare the new nodepool.yaml
nodepool = {
    'labels': labels['labels'],
    'diskimages': [],
    'providers': [],
}

# Import provider setting from sfconfig.yaml
for provider in sfconfig["nodepool"].get("providers", []):
    new_provider = {
        "name": provider["name"],
        "cloud": provider["name"],
        "clean-floating-ips": True,
        "images": [],
    }
    if "network" in provider and provider.get("network") is not None:
        new_provider["networks"] = [{"name": provider["network"]}]
    if "boot_timeout" in provider:
        new_provider["boot-timeout"] = provider["boot_timeout"]
    if "max_servers" in provider:
        new_provider["max-servers"] = provider["max_servers"]
    if "pool" in provider:
        new_provider["pool"] = provider["pool"]
    if "rate" in provider:
        new_provider["rate"] = provider["rate"]
    nodepool["providers"].append(new_provider)

# Import image from images.yaml
for image_provider in images:
    provider = None
    for new_provider in nodepool["providers"]:
        if new_provider["name"] == image_provider["provider"]:
            provider = new_provider
            break
    if provider is None:
        print("Missing provider named %s" % image_provider["provider"])
        continue
    for image in image_provider["images"]:
        if "private-key" in image:
            del image["private-key"]
    provider["images"] = image_provider["images"]

# Write nodepool.yaml
with open("nodepool/nodepool.yaml", "w") as of:
    of.write(yaml.dump(nodepool, default_flow_style=False))

# Move stuff to scripts
if not os.path.isdir("nodepool/scripts"):
    os.mkdir("nodepool/scripts", 0755)
p = glob.glob("nodepool/*.sh") + glob.glob("nodepool/*.txt") + \
    glob.glob("nodepool/*.py")
for script in p:
    os.rename(script, "nodepool/scripts/%s" % os.path.basename(script))

# Fix config-check job
default_jobs = open("jobs/_default_jobs.yaml").read()
fn = "/usr/local/bin/sf-nodepool-conf-merger.py"
fn2 = "/usr/local/bin/sf-nodepool-conf-merger.py"
for r, v in ((
    "cp ~jenkins/defconf/nodepool.yaml build/nodepool/",
    "cp ~jenkins/defconf/nodepool.yaml build/nodepool/_nodepool.yaml"), (
    """cp nodepool/*.yaml ../build/nodepool/
          WORKDIR=../build/nodepool/ %s merged.yaml
          nodepool -c ../build/nodepool/merged.yaml config-validate""" % fn,
    """%s ../build/nodepool/nodepool.yaml
          nodepool -c ../build/nodepool/nodepool.yaml config-validate""" % fn2
        )):
    default_jobs = default_jobs.replace(r, v)
with open("jobs/_default_jobs.yaml", "w") as of:
    of.write(default_jobs)

# Remove old yaml
os.unlink("nodepool/images.yaml")
os.unlink("nodepool/labels.yaml")
