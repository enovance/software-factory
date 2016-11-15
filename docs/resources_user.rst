.. _resources-user:

Managing resources via the config repository
============================================

The version 2.2.6 of Software Factory comes with a new way of managing
user groups, git repositories, git acls, and projects.

The resources mentioned above can be managed (created/deleted/updated)
via the CI/CD workflow of the config repository.

.. note::

   Warning : this feature is experimental and should not be used in production unless
   you are really confident about it.

.. note::

   This feature is going to replace legacy managesf REST endpoints project,
   memberships, groups. Legacy endpoints will be removed once this feature is
   known as stable.

.. note::

   It is not recommanded to use both, the legacy endpoints and the resources definition
   via the config repository. This is to avoid conflicts.

.. note::

   Only Gerrit is supported via this workflow, storyboard will be handled soon.

Advantages of managing resources via the config repository
----------------------------------------------------------

Resources are described via a strict YAML format that will reflect
the current state of the resources on the services. For instance
a group described in YAML will be created and provisioned with the
specified users on Gerrit. Any modifications on the group description
will be reflected on Gerrit. So looking at the YAML files you'll
see the real state of the SF services like Gerrit.

Furthermore using this config repository leverages the review workflow
through Gerrit so any modification on a resource YAML will need
an human review before being applied on the services. And finally
all modifications will tracked though the Git config repository history.

A SF operator will just need to approve a resource change and let
the config-update job execute to have the state applied on the
services.

Some details about the mechanics under the hood
-----------------------------------------------

The config repository is populated by default with a resources directory.
All YAML files that follow the expected format are loaded and taken in
account.

Let's say we want to create a group (called mygroup) of users on SF.
Here is a YAML file that describe this resource.

.. code-block:: yaml

  resources:
    groups:
      mygroup-id:
        name: mygroup
        members:
          - me@domain.com
          - you@domain.com
        description: This is the group mygroup

This file must be named with the extension .yml or .yaml under
the resources directory of the config repository.

Once done::

 * The default config-check job will execute and validate this new
   resource by checking its format and the validity of key's values provided.
 * The Verified label will then receive a note from the CI.
 * Everybody with access to the platform can comment and note you change.
 * Folks with rights of CR+2 and W+1 can approve the change.
 * Once approved and merged, the config-update job will take care
   of creating the group on the services like Gerrit.

It is a good practice to check the output of the validation (config-check job)
and the apply (config-update job) via the job console.

A more complete example
-----------------------

Below is a YAML file you can use as a starting point or as a reference.

.. code-block:: yaml

  resources:
    projects:
      ichiban-cloud:
        name: ichiban-cloud
        description: The best cloud platform engine
        contacts:
          - contacts@ichiban-cloud.io
        source-repositories:
          - ichiban-compute
          - ichiban-storage
        website: http://ichiban-cloud.io
        documentation: http://ichiban-cloud.io/docs
        issue-tracker: http://ichiban-cloud.bugtrackers.io
    repos:
      ichiban-compute:
        name: ichiban-compute
        description: The compute manager of ichiban-cloud
        acl: ichiban-dev-acl
      ichiban-storage:
        name: ichiban-storage
        description: The storage manager of ichiban-cloud
        acl: ichiban-dev-acl
    acls:
      ichiban-dev-acl:
        file: |
          [access "refs/*"]
            read = group ichiban-core
            owner = group ichiban-ptl
          [access "refs/heads/*"]
            label-Code-Review = -2..+2 group ichiban-core
            label-Code-Review = -2..+2 group ichiban-ptl
            label-Verified = -2..+2 group ichiban-ptl
            label-Workflow = -1..+1 group ichiban-core
            label-Workflow = -1..+1 group ichiban-ptl
            label-Workflow = -1..+0 group Registered Users
            submit = group ichiban-ptl
            read = group ichiban-core
            read = group Registered Users
          [access "refs/meta/config"]
            read = group ichiban-core
            read = group Registered Users
          [receive]
            requireChangeId = true
          [submit]
            mergeContent = false
            action = fast forward only
        groups:
          - ichiban-ptl
          - ichiban-core
    groups:
      ichiban-ptl:
        name: ichiban-ptl
        members:
          - john@ichiban-cloud.io
          - randal@ichiban-cloud.io
        description: Project Techincal Leaders of ichiban-cloud
      ichiban-core:
        name: ichiban-core
        members:
          - eva@ichiban-cloud.io
          - marco@ichiban-cloud.io
        description: Project Core of ichiban-cloud

Please note the users mentioned in the groups must have been
at connected once on your SF platform.

Resources are identified by an ID you provide like (from the example above)
*ichiban-dev-acl*. Any modification on this ID will be detected as a deletion
+ a creation. It is important to understand this ID is an UUID that need
to remain the same over the whole life of a resource.

Deleting a resource is as simple as removing it from the resources YAML files.
Updating a resource is as simple as updating it from the resources YAML files
and by taking care of keeping the same resource ID.

You can find details about resource models :ref:`here <config-resources-model>`
