.. _koji-integration-user:

Configure Jobs to integrate with Koji
=====================================

Integration with Koji
---------------------

Software Factory provides CI jobs to build RPM packages against
a standard Koji installation or CBS. These jobs use the tooling
stored in this Git repository:

https://softwarefactory-project.io/r/gitweb?p=koji-jobs.git;a=tree

More information about them can be read in the README.md file.

Slave image preparation
-----------------------

To have jobs interacting with Koji you first need to configure
a slave image to install the base tooling on it. This can
be done by using the *nodepool/kojiclient-base.sh* preparation
script provided by default in the config repository.

See the :ref:`Nodepool user documentation<nodepool-user>` for details
about how to setup a Nodepool slave with that preparation script.

Setup a packaging workflow with SF and Koji
-------------------------------------------

Every Git repository with a *.spec* file at its root can be
managed with that workflow.

The default provided file *config/jobs/_koji.yaml* proposes
two builders that use pkg-validate.sh and pkg-export.sh from the
koji-jobs tooling repo.

The builder *base-pkg-validation* can be used to build the
package against Koji in the "scratch build" mode and fetchs
for you the built artifacts (RPM(s)) on the slave for further testing.
This builder can be used in jobs run both in the SF check and
gate pipeline.

The builder *base-pkg-exportation* can be used to run
a build with the "non scratch build" mode to definitely
export the built packages inside the Koji target. This builder
is more adpated to be used in jobs run in the SF gate pipeline.

Usage example
-------------

Here is how to setup working jobs against CBS. This can be stored
in a new file under the config/jobs tree:

.. code-block:: yaml

 - job:
     name: 'package-validate'
     defaults: global
     builders:
       - base-pkg-validation:
           buildtarget: "dist-centos7"
           kojicmd: "cbs"
           reposcloneurl: "http://sftests.com/r"
       - shell: |
           echo "Built RPM have been fetched. Additionnal tests can be done here."
     triggers:
       - zuul
     wrappers:
       - credentials-binding:
         - file:
            credential-id: c784eddb-6193-4a90-a06d-a45131fd467a
            variable: CLIENTSECRET
     node: kojiclient-centos-7

 - job:
     name: 'package-export'
     defaults: global
     builders:
        - base-pkg-exportation:
            buildtarget: "dist-centos7"
            kojicmd: "cbs"
            reposcloneurl: "http://sftests.com/r"
       - shell: |
            echo "Exported !. Nothing more to do here."
     triggers:
       - zuul
     wrappers:
       - credentials-binding:
         - file:
            credential-id: c784eddb-6193-4a90-a06d-a45131fd467a
            variable: CLIENTSECRET
     node: kojiclient-centos-7

Please note that the client certificate for interacting with CBS
needs to be stored in the SF credential binding.

To trigger the above jobs for a project called *soft-distgit*
you need to create the following file under the config/zuul tree:

.. code-block:: yaml

 projects:
   - soft-distgit
     check:
       - package-validate
     gate:
       - package-export

Additionnal notes
-----------------

* These jobs should be considered experimental.
* New packages must be added in the build target under Koji with the
  "add-pkg" command prior to have the *package-export* succeed.
