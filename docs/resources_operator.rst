.. _resources-operator:

Managing resources via the config repository
============================================

Fetch missing resources from services to the config repository
--------------------------------------------------------------

Please read the introduction about this feature :ref:`here <resources-user>`

When resources are created outside the config/resources tree or when
you want to switch from the legacy endpoint usage to the new workflow then
you can use *resources.sh* to re-sync the resources tree.

The *get_missing_resources* mode of *resources.sh* will inspect services
to find resources that are not defined in the config/resources tree and
will propose via Gerrit a change that can be then approved to re-sync the
config/resources tree.

.. code-block:: bash

   /usr/local/bin/resources.sh get_missing_resources submit

Note the commit message of the proposed changed on Gerrit contains
the flag "sf-resources: skip-apply" that tell the config-update job
to skip the apply of the proposed resources. They are just merge
in the config/resources tree as they already exist on services.

Prevent usage of legacy endpoints
---------------------------------

If you choosed to use this workflow of managing resources via the config
repository in place of the legacy endpoint then it is safe to be sure
the platform policies does not allow access for users other than the admin
to the projects, memberships and groups endpoints. You should refer to this
:ref:`section <access_control>` to verify the policies and take the needed actions.
