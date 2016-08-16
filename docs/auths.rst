.. _authentication:

Sofware Factory Authentication
------------------------------

The admin user
^^^^^^^^^^^^^^

Admin user is used to create new repositories, modify ACLs and assign users to projects.


Github authentication
^^^^^^^^^^^^^^^^^^^^^

You have to register your SF deployment in Github to enable Github
authentication.

#. Login to your Github account, go to Settings -> Applications -> "Register new application"
#. Fill in the details and be careful when setting the authorization URL. It will look
   like this: http://yourdomain/auth/login/github/callback
#. Set the corresponding values in sfconfig.yaml:

.. code-block:: yaml

 authentication:
   oauth2:
     github:
       disabled: True
       client_id: "Client ID"
       client_secret: "Client Secret"
       # the github provider also lets you filter users logging in depending
       # on the organizations they belong to. Leave blank if not necessary
       github_allowed_organizations:


Local user management
^^^^^^^^^^^^^^^^^^^^^

For simple deployments without a Identity Provider,
you can manage the users through the SFManager command-line utility in the :ref:`User Management <sfmanager-user-management>` section.
(except for the default admin user, defined in the sfconfig.yaml file)
can be done through the SFmanager command-line utility :ref:`User management <sfmanager-user-management>`. This backend allows to have
a user database locally.


Admin user password change
^^^^^^^^^^^^^^^^^^^^^^^^^^

To change the admin user password, you need to edit /etc/puppet/hiera/sf/sfconfig.yaml and change the value
of `admin_password`. Then call `sfconfig.sh` to set the password.


Redmine API key change
^^^^^^^^^^^^^^^^^^^^^^

To change the Redmine API key, you need to edit /etc/puppet/hiera/sf/sfcreds.yaml and change the value of
`creds_issues_tracker_api_key`. Then call `sfconfig.sh` to update the key.


Github Secret change
^^^^^^^^^^^^^^^^^^^^

To change the Github App Secret, you need to login to your Github account, got to Settings -> Applications ->
"Reset client secret". Then update /etc/puppet/hiera/sf/sfconfig.yaml and call `sfconfig.sh`.


Local database access credencials
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each service credencials for mysql database access are stored in /etc/puppet/hiera/sf/sfcreds.yaml.
You can use the `sf_rotate_mysql_passwords.py` command line to replace them all and restart services.
