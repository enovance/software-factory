Contents:

.. toctree::

Migrating to Software Factory
=============================

It is relatively easy to migrate a previous work environment to a new
instance of Software Factory. Here are a few strategies available.

Migrating a repository
----------------------

Git repository
..............

Simply follow the instructions in :doc:`the managesf documentation<managesf>`
about creating a project on SF. You can either specify the upstream repository
to clone, or just create an empty project and then add Software Factory as a new
*remote* on your local copy of the repository, and push to this remote.

Example
'''''''

.. code-block:: bash

 $ sf-manage --url <http://sfgateway.dom> --auth-server-url <http://sfgateway.dom> --auth user:password create --name myproject
 $ cd /path/to/localcopy
 $ git remote add softwarefactory http://sfgateway.dom/r/p/myproject.git
 $ git push softwarefactory

You might want to actually replace the 'origin' remote with software factory;
you will need to remove the previous one with 

.. code-block:: bash

 $ git remote rm origin

See the git documentation for more details: http://git-scm.com/book/en/v2/Git-Basics-Working-with-Remotes

Non-Git repositories
....................

The Gerrit review service only supports git-based repositories. Therefore it is
necessary to convert your project's version control system to git prior to
using Software Factory. It is a common task, so utilities and documentation
about it are abundant, for example:

* **subversion** to git: https://www.atlassian.com/git/tutorials/migrating-overview
* **mercurial** to git: http://stackoverflow.com/questions/10710250/converting-mercurial-folder-to-a-git-repository
* **bazaar** to git: https://dgleich.wordpress.com/2011/01/22/convert-bazaar-to-git/

Once the conversion is complete, follow the instructions to migrate a git
repository without an upstream repo as described above.

Migrating issues
----------------

Software Factory comes with a python library called sfmigration. It simplifies
the task of importing issues from many issue trackers.

To install the library:

.. code-block:: bash

 $ cd software-factory/tools/sfmigration
 $ python setup.py install

Migration scripts for a variety of issue trackers can be found under the "examples"
subdirectory of the project. They require a config.ini file, each different for
specific issue trackers or data sources, so please see the comments in-line with
the sample ini files provided.

Once the ini file is filled appropriately, the script can be launched with

.. code-block:: bash

 $ cd software-factory/tools/sfmigration/examples/from_<issue_tracker>/
 $ python export_issues.py

Redmine API limitations
.......................

Not every functionality is exposed through Redmine's REST API, so some resources
cannot be migrated programmatically. For a complete and up-to-date list of
available resources, see http://www.redmine.org/projects/redmine/wiki/Rest_api

sfmigration library limitations
...............................

* Currently, the only issue trackers supported are Redmine (non SF) and Github.
* Issue attachments are not imported.
* Issue relations and dependencies are not imported.

Migrating gate jobs
-------------------

<TODO>
