.. toctree::

Configure gerritbot for IRC notification
========================================

System configuration
--------------------

To start the service:

* Add the gerritbot role to the inventory: /etc/puppet/hiera/sf/arch.yaml
* Set the gerritbot configuration in /etc/puppet/hiera/sf/sfconfig.yaml
* Re-apply: sfconfig.sh

Project configuration
---------------------

Once the service is running, you can configure the irc channel to get notification:

* git clone the config-repository
* add a new file or edit one in config/gerritbot directory::

  irc-channel-name:
    events:
      - patchset-created
      - change-merged
    projects:
      - myproject
    branches:
      - master

* submit and merge the config change.
* enjoy
