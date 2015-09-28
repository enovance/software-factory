.. toctree::

Deploy Software Factory
=======================

SF is image based. Each release is a new archive that includes
a complete operating system and all services pre-installed.

While SF really benefits from running on top of OpenStack, the image
can also be used standalone.

Download the latest image from: http://softwarefactory-project.io/releases


Requirements
------------

To deploy SF you need:

* Access to an OpenStack Cloud or standalone CentOS 7
* FQDN required by web interface OAuth authentication callback
* Minimum 40GB of hardrive and 4GB of memory with swap.
* Recommended 80GB of hardrive and 80GB of memory


Deploy on top of OpenStack
--------------------------

Install image
.............

Always make sure to use the last available tag, the example below use the 2.0.0 version:

.. code-block:: bash

 $ wget http://os.enocloud.com:8080/v1/AUTH_70aab03f69b549cead3cb5f463174a51/edeploy-roles/softwarefactory-C7.0-2.0.0.img.qcow2
 $ wget http://os.enocloud.com:8080/v1/AUTH_70aab03f69b549cead3cb5f463174a51/edeploy-roles/softwarefactory-C7.0-2.0.0.digest
 # gpg --keyserver keys.gnupg.net --recv-key 1C3BAE4B
 $ gpg --verify softwarefactory-C7.0-2.0.0.digest
 $ glance image-create --disk-format qcow2 --container-format bare --name sf-2.0.0 --file softwarefactory-C7.0-2.0.0.img.qcow2


Deploy with Heat
................

A Heat template is provided to automate the deployment process. You need to specify the image uuid and network uuid as
well as the FQDN of the deployment (domain parameter):

.. code-block:: bash

 $ wget http://os.enocloud.com:8080/v1/AUTH_70aab03f69b549cead3cb5f463174a51/edeploy-roles/softwarefactory-C7.0-2.0.0.hot
 $ heat stack-create ./softwarefactory-C7.0-2.0.0.hot -P key_name=SSH_KEY;domain=fqdn_of_deployment;image_id=GLANCE_UUID;sf_root_size=80;ext_net_uuid=NETWORK_UUID


Deploy with Nova
................

When Heat is not avaiable, SF can also be deployment manually:

* Start the instance
* Connect to the instance with ssh.
* Edit the configuration sfconfig.default. Set the fqdn (required by OAuth authentication callback) and admin username/password.
* Run configuration script.

.. code-block:: bash

 $ nova boot --flavor m1.large --image sf-2.0.0 sf-2.0.0 --key-name SSH_KEY
 $ ssh -A root@sf_instance
 [root@managesf ~]# cd bootstraps
 [root@managesf bootstraps]# vim sfconfig.default
 [root@managesf bootstraps]# ./bootstraps.sh


Standalone deployment
---------------------

The image can also be used standalone. Either installed to baremetal (not covered in this documentation), either
within LXC containers:

.. code-block:: bash

 $ git clone https://softwarefactory-project.io/r/software-factory
 $ cd software-factory
 $ git checkout 2.0.0
 $ ./sfstack.sh

This method of deployment is mostly useful for testing, it uses default configuration with domain name "tests.dom" and
admin username/password: "user1/userpass"


Deployment reconfiguration
--------------------------

To change the FQDN, enable github replication, authentication backend or cloud provider, you need to edit sfconfig.yaml settings.
The file is available here: /etc/puppet/hiera/sfconfig.yaml.
The configuration script (bootstrap.sh) needs to executed.


Network Access
--------------

All network access goes through the main instance (called managesf). The FQDN
used during deployment needs to resolved to instance floating ip. SF network
access goes through TCP ports:

* 22 for ssh access to reconfigure and update deployment
* 80/443 for web interface, all services are proxyfied on the managesf instance
* 29418 for gerrit access to submit code review
* 45452 for Jenkins swarm slave connection

Note that Heat deployment and Standalone deployment automatically configure
security group rules to allow these connections to managesf.


SF is now ready to be used, dashboard is available to https://FQDN and admin user can authenticate using "Internal Login"
