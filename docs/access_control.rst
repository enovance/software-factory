.. _access_control:

Access control
==============

Software Factory comes with a policy engine allowing an operator to define who
can do what on the manageSF REST API.

The config repository includes a template policy.json that shows the default
policies on Software Factory. Modifying these rules will override the default
behavior.

How to change access policies
-----------------------------

* git clone the config-repository
* edit the config/policies/policy.json file to suit your needs
* submit and merge the config change
* the policies will be updated once the config-update job has run its course.

Writing custom rules
--------------------

The policy engine is based on OpenStack's oslo.policy. You can therefore refer
to the documentation of this project for further information: http://docs.openstack.org/developer/oslo.policy/

The rules are defined as such:

.. code-block:: json

  "rule_name": "rule_description"

where rule_description is a boolean combination of one or more fundamental blocks.
Fundamental blocks can have the following form:

.. code-block:: json

  "rule:rule_name"

to refer to a previously created rule or

.. code-block:: json

  "property:value"

where 'property' is a property of the user requesting the action (for example
'username', 'group', or 'is_authenticated') and 'value' a hard-coded value (for
example 'True' or 'user3') or the value of the target property (for example %(username)s
or %(project)s).

The following user properties are supported:

* username: the username of the requesting user on Software Factory
* group: the groups the requesting user belongs to. The rule 'group:A' will 
  match if A is one of the groups the user belongs to.
* is_authenticated: will match to True if the user is logged in.

The following target properties are supported:

* %(username)s: the username of the user on which the action would apply (if relevant)
* %(project)s: the project on which the action would apply (if relevant)
* target.group: the group targeted by the action (if relevant, typically for membership operations)
  For example, to check if the targeted group is the targeted project's dev group: target.group:%(project)s-dev
* %(group)s: the group targeted by the action. For example, to check if the requesting user belongs to the
  target group: group:%(group)s

Default rules
-------------

The following default rules are set for convenience. They can be overridden if
necessary.

* admin_or_service: allow the admin user or the SF service user only
* admin_api: allow the admin user only
* is_owner: allow the user herself only (applies to user-related API operations only)
* admin_or_owner: allow the user owning the resource or the admin only (applies to user-related API operations only)
* ptl_api: allow PTL users of this project only (applies to project-related API operations only)
* core_api: allow core users of this project only (applies to project-related API operations only)
* dev_api: allow dev users of this project only (applies to project-related API operations only)
* contributor_api: allow PTL, core or dev users of this project only (applies to project-related API operations only)
* authenticated_api: allow any logged in user
* any: allow anybody
* none: allow nobody

API rules
---------

These are the names of the API rules supported in Software Factory. Each can
be set to fit your use cases.

* Project API
  * managesf.project:get_one
  * managesf.project:get_all
  * managesf.project:create
  * managesf.project:delete
* Backup API
  * managesf.backup:get
  * managesf.backup:create
* Restoring backups API
  * managesf.restore:restore
* Project group memberships API
  * managesf.membership:get
  * managesf.membership:create
  * managesf.membership:delete
* Group API
  * managesf.group:get
  * managesf.group:create
  * managesf.group:update
  * managesf.group:delete
* Pages API
  * managesf.pages:get
  * managesf.pages:create
  * managesf.pages:delete
* Local User backend API
  * managesf.localuser:get
  * managesf.localuser:create_update
  * managesf.localuser:delete
  * managesf.localuser:bind
