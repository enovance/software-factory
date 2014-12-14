Product Life Cycle
==================

Deployment
----------

Using a stable tagged source code tree:

Upload images
~~~~~~~~~~~~~
Images are fetch from publication container and uploaded to glance.
If needed, images can be rebuilt using edeploy roles

Parameter
~~~~~~~~~
The Heat stack need these parameter:
* the ssh public key for instances access
* instances flavor && disk size
* the sfconfig.yaml:
** administrator account configuration
** domain name
** other tunings (e.g., cookies timeout, smtp relay for mail notification, ...)

Stack
~~~~~
Heat will boot all the required instances and cloudinit will initiate the bootstrap from the puppetmaster:
* prepare puppet hiera configuration
* wait for all node
* start puppet agents
* run rspec tests

Note that bootstrap is automated and requires no actions.


Functional tests
----------------
Functional tests can be run from puppetmaster to make sure the plateform is behaving corectly.


Backups
-------
Backup can be performed using the api and could be restore on a same version deployment.

A backup contains:
* Databases (bug tracker, gerrit pending reviews, ...)
* Project source code
* Configuration


Upgrade
-------

Using a more recent source code tree:

Provision new images
~~~~~~~~~~~~~~~~~~~~
New images are fetch on the install-server-vm instance

Perform the upgrade
~~~~~~~~~~~~~~~~~~~
TBD
