.. toctree::

Contributing to Software Factory
================================

How can I help?
---------------

Thanks for asking. Let's find a place for you!

First you should join our communication forums:

* Join us on IRC: You can talk to us directly in the #softwarefactory channel
  on freenode.
* Read the official Software Factory documentation. You can access it there :
  http://softwarefactory.enovance.com/_docs/
* Reporting problems found in the documentation could be a good way to
  help and contribute at the begining. To report those problems feel free to
  contact us on Freenode or even create a bug on :
  http://softwarefactory.enovance.com/_redmine/projects/software-factory

Then you should deploy your own softwarefactory. A good way to ease the installation
of development environment is to use _`sfstack`.

sfstack
-------

Sfstack is a suite of scripts that you can download from our public
softwarefactory instance. The idea is to install a Ubuntu 14.04 in a
VM somewhere, and start the *sfinstall.sh* script in order to prepare
a development environment.

.. code-block:: bash

 $ git clone http://softwarefactory.enovance.com/r/sfstack
 $ cd sfstack
 $ sudo ./sfinstall

Sfinstall script will install all the dependencies needed and fetch the
sofwarefactory source code. Note that we use that project to build our
jenkins slaves to run softwarefactory functionnal tests.

After a successful run of *sfinstall.sh* you will find the
clone directory of softwarefactory in /srv

You can then jump to _`How to deploy SF within LXC` to learn
how to start a local softwarefactory, but skip the dependencies
download instruction as the *sfinstall.sh* script already done that for you.

How to run the tests locally
----------------------------

We have to three kinds of tests that are ::

 * Unit tests
 * Functional tests againt a LXC deployment
 * Functional tests againt an Openstack HEAT deployment

Before sending a patch to the upstream softwarefactory code, we advise
you to run the LXC tests and unitests.

.. code-block:: bash

  $ cd /srv/softwarefactory
  $ ./run_tests.sh # unitests
  $ DEBUG=1 SF_DIST=CentOS ./run_functional-tests.sh # functional tests

The functional tests will start LXC containers on the local VM to simulate
as closed as possible a HEAT deployment.

How to contribute
-----------------

* Connect to softwarefactory.enovance.com using your Github account
* Check the bugtracker and the pending reviews
* Submit your change

.. code-block:: bash

  $ cd /srv/softwarefactory
  $ git-review -s # only relevant the first time to init the git remote
  $ git checkout -b"my-branch"
  $ # Hack the code, create a commit on top of HEAD ! and ...
  $ git review # Summit your proposal on softwarefactory.enovance.com

Have a look to http://softwarefactory.enovance.com/_r/ where you will find the patch
you have just summited. Automatic tests are run against it and Jenkins/Zuul will
report a status as comments on the gerrit page related to your patch. You can
also check http://softwarefactory.enovance.com/_zuul/ to follow the test process.

Note that Software Factory is developed using Software Factory. That means that you can
contribute to SF in the same way you would contribute to any other project hosted
on SF: :ref:`contribute`.

Feel free to hack the code, update your test deployment and contribute !
