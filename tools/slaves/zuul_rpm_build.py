#!/bin/env python
#
# Copyright 2016 Red Hat
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import argparse
import logging
import os
import re
import subprocess
import sys


class ZuulRpmBuild:
    log = logging.getLogger('zuulrpm.builder')

    def execute(self, argv):
        self.log.debug("Running %s" % argv)
        if subprocess.Popen(argv).wait():
            self.log.error("Command %s failed" % argv)
            raise RuntimeError()

    def parse_arguments(self, args=sys.argv[1:]):
        p = argparse.ArgumentParser(description='Zuul RPM builder')
        p.add_argument("--pipeline",
                       default=os.environ.get('ZUUL_PIPELINE', 'check'))
        p.add_argument("--changes",
                       default=os.environ.get('ZUUL_CHANGES', ''))
        p.add_argument("--source", default=os.environ.get('RPM_SOURCE'),
                       help="The git server to fetch projects from")
        p.add_argument("--output", default=os.environ.get('RPM_REPO'),
                       help="The repository to publish package")
        p.add_argument("--local_output", default="zuul-rpm-build",
                       help="The directory to locally store build")
        p.add_argument('--verbose', action='store_true', help='verbose output')

        self.args = p.parse_args()

    def setup_logging(self, verbose=False):
        if verbose:
            logging.basicConfig(level=logging.DEBUG)
        else:
            logging.basicConfig(level=logging.INFO)

    def build_srpm(self, distgit, change_source0):

        specs = filter(lambda x: x.endswith(".spec"), os.listdir(distgit))
        if len(specs) != 1:
            self.log.error("%s: Incorrect number of .spec files: %s" %
                           (distgit, specs))
            exit(1)
        specfile = "%s/%s" % (distgit, specs[0])

        if change_source0:
            spec = open(specfile).read()
            spec = re.sub(r"Source0:.*", r"Source0: HEAD.tgz", spec)
            open(specfile, "w").write(spec)

        self.log.info("%s: Fetching sources" % distgit)
        self.execute(["spectool", "-g", "-C", distgit, specfile])

        self.log.info("%s: Building SRPM" % distgit)
        self.execute(["mock", "--no-clean", "--no-cleanup-after",
                      "--buildsrpm",
                      "--resultdir", self.args.local_output,
                      "--spec", specfile, "--sources", distgit])

    def build_rpm(self, distgit):
        for srpms in filter(lambda x: x.endswith('.src.rpm'),
                            os.listdir(self.args.local_output)):
            if srpm in self.srpms:
                continue
            self.execute(["mock", "--no-clean", "--no-cleanup-after",
                          "--postinstall", "--rebuild",
                          "--resultdir", self.args.local_output,
                          "%s/%s" % (self.args.local_output, srpm)])
            self.log.info("%s: Building RPM" % srpm)
            self.srpms.add(srpm)

    def build(self, project):
        if project.endswith("-distgit"):
            distgit = project
        else:
            self.log.info("%s: Project is not a distgit, "
                          "now finding the -distgit repo" % project)
            distgit = "%s-distgit" % project
            if self.args.source:
                try:
                    self.execute(["zuul-cloner", self.args.source, distgit])
                except RuntimeError:
                    self.log.error("Couldn't find %s" % distgit)
                    exit(1)
            elif not os.path.isdir(distgit):
                self.log.error("Couldn't find distgit project")
                raise RuntimeError()
            self.log.info("%s: Creating source0 with HEAD" % project)
            self.execute(["tar", "-cz", "--exclude", ".git",
                          "-f", "%s/%s-HEAD.tgz" % (distgit,
                                                    project.replace('/', '-')),
                          "-C", os.path.dirname(project),
                          os.path.basename(project)])

        self.build_srpm(distgit, distgit != project)
        self.build_rpm(distgit)

    def main(self):
        self.parse_arguments()
        self.setup_logging(verbose=self.args.verbose)
        if not self.args.changes:
            self.log.info("No ZUUL_CHANGES defined, building %s" % os.getcwd())
            project = os.path.basename(os.getcwd())
            os.chdir("..")
            self.args.changes = "%s:master:refs/HEAD" % project

        if not os.path.isdir(self.args.local_output):
            os.mkdir(self.args.local_output, 0700)

        self.log.info("Cleaning mock chroot")
        self.execute(["mock", "--clean"])

        self.srpms = set()
        self.rpms = set()

        for change in self.args.changes.split('^'):
            project, branch, ref = change.split(':')
            if self.args.source:
                self.execute(["zuul-cloner", self.args.source, project])
            elif not os.path.isdir(project):
                self.log.error("Couldn't find %s" % project)
                exit(1)
            self.build(project)

        self.log.info("Creating final repository")
        os.chdir(self.args.local_output)
        self.execute(["createrepo"])

if __name__ == "__main__":
    ZuulRpmBuild().main()
