Contents:

.. toctree::

Frequently Asked Questions
==========================

What is edeploy ?
.................

Edeploy is a legacy tool to manage deployment of image based system.
It build and manage the lifecycle of an image that comes with everything
pre-installed so that the whole system can be verified and tested
without Internet access. That means each new changes results in a new
image that has been continuously tested:

* a full deployment + functional tests
* an upgrade test based on the previous version
* an openstack integration test based on rdo where nodepool and swift
  artifacts export features are tested.


What is the added value of Software Factory ?
.............................................

* Ready to use CI system that works out of the box
* System configuration interface using yaml and puppet/ansible
* Project configuration interface using code review to manage
  jobs, zuul layouts and nodepool project configuration
* REST API to manage project creation and users ACL provisioning
* SSO with ldap/github/launchpad/keystone authentication backend
* Backup and automatic upgrade mechanism (fully tested in sf CI)
* Baremetal, LXC, KVM or OpenStack based deployment
* Fast reproducible setup (3/5 minutes with lxc, 15 minutes with heat)
* Openstack integration to run slave (nodepool) and store artifacts (swift)


Why sf integrates redmine and can it be disabled ?
..................................................

SF goal is to propose a complete workflow to produce software,
including an issue tracking system integrated with the ci workflow.

However since most development team already have an issue tracker,
an on-going effort to support external issue tracker is still in progress.
The main challenge is to do functional testing using mocked resources
to simulate an external tracker.
