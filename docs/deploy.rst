.. toctree::

Deploy Software Factory
=======================

SF is image based. Each release is a new archive that includes
a complete operating system and all services pre-installed.

While SF really benefits from running on top of OpenStack, the image
can also be used standalone.

Download the latest image here:
  http://os.enocloud.com:8080/v1/AUTH_70aab03f69b549cead3cb5f463174a51/edeploy-roles


Install image
-------------

OpenStack:

.. code-block:: bash

 $ wget -c http://os.enocloud.com:8080/v1/AUTH_70aab03f69b549cead3cb5f463174a51/edeploy-roles/softwarefactory-C7.0-2.0.0.img.qcow2
 $ glance image-create --disk-format qcow2 --container-format bare --name sf-2.0.0 --file softwarefactory-C7.0-2.0.0.img.qcow2

LXC:

.. code-block:: bash

 $ git clone http://softwarefactory.enovance.com/r/software-factory
 $ cd software-factory
 $ ./fetch_image.sh


Start instance
--------------

OpenStack:

.. code-block:: bash

 $ nova boot --flavor m1.large --image sf-2.0.0 sf-2.0.0 --key-name SSH_KEY


OpenStack Heat:

.. code-block:: bash

 $ wget -c http://os.enocloud.com:8080/v1/AUTH_70aab03f69b549cead3cb5f463174a51/edeploy-roles/softwarefactory-C7.0-2.0.0.hot
 $ heat stack-create ./softwarefactory-C7.0-2.0.0.hot


LXC:

.. code-block:: bash

 $ cd deploy/lxc; ./deploy.py init


Configure
---------

Once the image is up and running, the services are ready to be deployed:

* Connect to the main instance
* Edit the configuration to set domain name and other settings
* Run deployment script for the architecture

.. code-block:: bash

 $ ssh root@main_instance
 [root@managesf ~]# cd bootstraps
 [root@managesf bootstraps]# vim sfconfig.yaml
 [root@managesf bootstraps]# ./bootstraps.sh 1node-allinone

After this process is complete, SF is ready to used.


Network Access
--------------

TCP Port 80, 443, 29418 and 45452 needs to be open.
Domain name used during deployment needs to match ip address.

Assuming you have not modified the default domain in sfconfig.yaml "tests.dom",
add an entry to your workstation's /etc/hosts to resolve tests.dom
to the public IP of the instance.

Then open your browser on http://tests.dom (TCP/80 must be allowed
from your workstation to the VM). Assuming the used domain is tests.dom,
you can use the default pre-provisioned users that are user1, user2,
user3 with 'userpass' as password. User *user1* is the default administrator
in this LXC SF deployment.

Default users are only usable if the domain used is "tests.dom". If
you want to deploy in production do not use this default domain.


LXC deployment lifecycle
------------------------

Using *deploy/lxc/deploy.py* with the *init* argument is only needed for the first
bootstrap of the SF instance. Indeed some specific operations are needed during the
first start of a SF instance.

If you need to stop your SF instance then use the *stop* argument. This will stop
the LXC containers, umount the aufs mounts, delete the bridge and clean iptables.

If you need to start a SF instance (previous bootstrapped with *init*) use the *start*
argument. This will create the bridge, mount the overlayfs mount, start the
containers and setup the iptables rules.

The *destroy* argument should be only used if you don't care about the data
you stored on your SF instance (projects, issues, ...).


The default admin user
----------------------

You need a default admin user to create new repositories, modify ACLs and
assign users to projects.  By default this is *user1*, defined in
"bootstrap/sfconfig.yaml". You can change this user before deploying SF, and
even use an existing Github username.  If an user logins using the login form (with
username and password) it will be authenticated locally, even if there is no
LDAP backend defined.
The password of this user is hashed and salted and stored on the managesf node.
By default this is *userpass*.  Use the following command to compute a new
password:

.. code-block:: bash

 $ mkpasswd -m sha-512 "secret_password"

The password is also stored in plaintext in bootstrap/sfconfig.yaml, because it
is needed by Puppet to create default accounts. You can set the plaintext
password to "" after the initial deployment is done (both in
bootstrap/sfconfig.yaml and in  /etc/puppet/hiera/sf/sfconfig.yaml).

Github authentication
---------------------

You have to register your SF deployment in Github to enable Github
authentication.

#. Login to your Github account, go to Settings -> Applications -> "Register new application"
#. Fill in the details and be careful when setting the authorization URL. It will look
   like this: http://yourdomain/auth/login/github/callback
#. Set the corresponding values in bootstrap/sfconfig.yaml:

.. code-block:: none

 github_app_id: "Client ID"
 github_app_secret: "Client Secret"
 github_allowed_organization: comma-separated list of organizations that are allowed to access this SF deployment.

Note that a user has to be member of at least one of this organizations to use this SF deployment.
Leave empty if not required.

Local user management
---------------------

For simple deployments without a LDAP backend for users or github authentication,
user management (except for the default admin user, defined in the sfconfig.yaml file)
can be done through the SFmanager command-line utility.

The following operations must be performed as the admin user.

Adding a user:

.. code-block:: bash

 sfmanager user add --username=X --password=Y --email=Z@abc.net --fullname=xxx --ssh-key=/path/to/pub_key

Deleting a user:

.. code-block:: bash

 sfmanager user delete --username=X

The following operation can be performed by the admin user or the user himself:

Updating a user's details (password, ssh key ...):

.. code-block:: bash

 sfmanager user update --username=X --password=YY

If --password is used but no value is set in the command line, the user will be
prompted for it.
When updating your own details, --username is not mandatory.

Please not that currently only a password change will have an effect. In order
to change your ssh keys, do it in the gerrit preferences page.

Setup replication to GitHub
---------------------------

Sometimes you want to have an external repository that Gerrit should push
changes to, for example a repository on Github where you want to host your code
too.  This is a short guide howto setup a replication for one or more
repositories to an external git server, in this case Github.

1. Create a new SSH key and add the public key to your project "Deploy keys"
project on Github (in Settings->Deploy Keys). The private key should be stored
with permission 600 somewhere in /home/gerrit/site_path/etc

.. code-block:: bash

 ssh-keygen -f /home/gerrit/site_path/etc/github_repo_name_key

2. Create a SSH config entry in /home/gerrit/.ssh/config:

.. code-block:: guess

 Host "github_repo_name"
     Hostname github.com
     PreferredAuthentications publickey
     IdentityFile /home/gerrit/site_path/etc/github_repo_name_key.pub
     StrictHostKeyChecking no
     UserKnownHostsFile /dev/null

3. Create the following config in /home/gerrit/site_path/etc/replication.config:

.. code-block:: guess

 [remote "github_repo_name"]
 url = git@github_repo_name:GITHUB_USERNAME/github_repo_name.git
 push = +refs/heads/*:refs/heads/*
 push = +refs/tags/*:refs/tags/*
 projects = test-sf

Please note that the hostname is not the real hostname from github in this case.
It's the name that is also used in the SSH configuration; this makes it possible
to use different SSH deploy keys for different repositories in Github -
otherwise you could only use a single hostname.

4. Restart Gerrit

.. code-block:: bash

 service gerrit restart

5. Trigger replication (from my host, using my identity):

.. code-block:: bash

 ssh -p 29418 softwarefactory.hostname replication start test-sf --wait

The initial replication takes some time, but finally it will respond with
something like this:

.. code-block:: guess

    Replicate test-sf to test-sf.github, Succeeded!
    ----------------------------------------------
    Replication completed successfully!

Please note that Gerrit overwrites all commits that are merged elsewhere. That
means that merged Pull Requests in Github itself will be lost in the history
(technically they are still there, but no longer visible).
