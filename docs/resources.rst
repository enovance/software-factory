.. _config-resources-model:

Available resources models
==========================

Containers / Resources mapping
------------------------------
* Model type: **git** can only be defined in container: **repos**
* Model type: **acl** can only be defined in container: **acls**
* Model type: **project** can only be defined in container: **projects**
* Model type: **group** can only be defined in container: **groups**

Resources
---------


project
^^^^^^^

The project resource is used to describe a project. It can be seen as the top level resource type in in this model. You can use it reference multiple Git repositories and multiple link to external resources like a project website and the issues tracker website.

Below are the list of keys available for this resource.


website
"""""""
* **Description:** The project web page link
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** ""

mailing-lists
"""""""""""""
* **Description:** Email addresses of project mailing lists
* **Type:** <type 'list'>
* **Authorized value:** RE(.+@.+)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** []

issue-tracker
"""""""""""""
* **Description:** The project issue tracker link
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** ""

source-repositories
"""""""""""""""""""
* **Description:** Code source repositories related to the project
* **Type:** <type 'list'>
* **Authorized value:** RE(.+)
* **Mandatory key:** True
* **Mutable key:** True

name
""""
* **Description:** The project name
* **Type:** <type 'str'>
* **Authorized value:** RE(^([a-zA-Z0-9\-_\./])+$)
* **Mandatory key:** True
* **Mutable key:** True

contacts
""""""""
* **Description:** Email addresses of project main contacts
* **Type:** <type 'list'>
* **Authorized value:** RE(.+@.+)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** []

documentation
"""""""""""""
* **Description:** The project documentation link
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** ""

description
"""""""""""
* **Description:** The project description
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** True
* **Mutable key:** True

acl
^^^

The acl resource is used to store a Gerrit ACL. The acl can be share between multiple git repositories.Group mentionned in inside the acl file key must be referenced by there ID under the groups key. Do not provide the description entry in the acl file to keep them shareable between git repositories if needed.

Below are the list of keys available for this resource.


groups
""""""
* **Description:** The list of groups on which this ACL depends on
* **Type:** <type 'list'>
* **Authorized value:** RE(.+)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** []

file
""""
* **Description:** The Gerrit ACL content
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** True
* **Mutable key:** True

git
^^^

The git resource is used to describe a git repository hosted on Gerrit. An acl ID can be provided via the acl key.

Below are the list of keys available for this resource.


acl
"""
* **Description:** The ACLs id
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** ""

name
""""
* **Description:** The repository name
* **Type:** <type 'str'>
* **Authorized value:** RE(^([a-zA-Z0-9\-_\./])+$)
* **Mandatory key:** True
* **Mutable key:** False

description
"""""""""""
* **Description:** The repository description
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** No description provided

group
^^^^^

The group resource is used to define a group of known user on the platform. Users must be referenced by their email address. A group can be share between multiple acls.

Below are the list of keys available for this resource.


name
""""
* **Description:** The group name
* **Type:** <type 'str'>
* **Authorized value:** RE(^([a-zA-Z0-9\-_\./])+$)
* **Mandatory key:** True
* **Mutable key:** False

members
"""""""
* **Description:** The group member list
* **Type:** <type 'list'>
* **Authorized value:** RE(.+@.+)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** []

description
"""""""""""
* **Description:** The group description
* **Type:** <type 'str'>
* **Authorized value:** RE(.*)
* **Mandatory key:** False
* **Mutable key:** True
* **Default value:** ""
