.. toctree::

Configure slave nodes for Jenkins
=================================

Automatic setup via the Jenkins UI
----------------------------------

Manual setup of a Jenkins slave
-------------------------------

If you need to setup one or more Jenkins slaves, you can follow the process below:

To substitute:

 - <gateway>: The same name you access the SF Web user interface.
 - <password>: The password of the Jenkins user.

.. code-block:: bash

 $ # Add the jenkins user
 $ sudo adduser --disabled-password --home /var/lib/jenkins jenkins
 $ # You can setup sudo for the jenkins user in order to have the possibility
 $ # to run command via sudo in your tests.
 $ sudo -i
 $ cat << EOF > /etc/sudoers.d/jenkins
   Defaults   !requiretty
   jenkins    ALL = NOPASSWD:ALL
   EOF
 $ chmod 0440 /etc/sudoers.d/jenkins
 $ exit
 $ # Download and start the swarm client
 $ sudo -u jenkins curl -o /var/lib/jenkins/swarm-client-1.22-jar-with-dependencies.jar \
    http://maven.jenkins-ci.org/content/repositories/releases/org/jenkins-ci/plugins/\
    swarm-client/1.22/swarm-client-1.22-jar-with-dependencies.jar
 $ sudo -u jenkins bash
 $ /usr/bin/java -Xmx256m -jar /var/lib/jenkins/swarm-client-1.22-jar-with-dependencies.jar \
   -fsroot /var/lib/jenkins -master http://<gateway>:8080/jenkins -executors 1 -username jenkins -password \
   <password> -name slave1 &> /var/lib/jenkins/swarm.log &


You should check the swarm.log file to verify the slave is well connected to the jenkins master. You can
also check the Jenkins Web UI in order to verify the slave is listed in the slave list.

Then you can customize the slave node according to your needs to install components
required to run your tests.

The Jenkins user password can be fetched from the file sfcrefs.yaml on the
puppetmaster node. You can find it with the following command or request it from
your Software Factory administrator.

If you want this slave authorizes jobs to be run concurrently then modify the "executors"
value.

.. code-block:: bash

 $ grep creds_jenkins_user_password sf-bootstrap-data/hiera/sfcreds.yaml


Using nodepool to manage Jenkins slaves
---------------------------------------

Nodepool automates management of Jenkins slave. It automatically prepares and
starts VMs that are used for a single test. After each test the VM is destroyed
and a fresh one is started for the next test. Nodepool also prepares the images
that are used for testing, for example when additional packages are required.

To do this, an account on an OpenStack cloud is required and credentials need to
be known by nodepool.

There are basically two options to configure nodepool. The easiest way to test
nodepool is to use a LXC environment and add a file ~/sfconfig.local with the
following content::

 nodepool_os_username: 'username'
 nodepool_os_password: 'secret'
 nodepool_os_project_id: 'tenant'
 nodepool_os_auth_url: 'http://mykeystoneendpoint:35357/v2.0'

If you don't use a LXC environment, you need to modify
puppet/hiera/nodepool.yaml and change settings there.

By default an image named "centos7" is required and used by nodepool.  If there
is none yet, create one and use the following URL as source:
http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2

If you want to test nodepool with SF itself, do the following::

 cd software-factory
 DEBUG=1 ./run_functional-tests.sh
 # enable public network access after LXC containers
 sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

Once the deployment is up and running you should see a new VM running on the
OpenStack cloud. It will take some time before the nodepool image is ready,
because of the sfstack install script and downloading of the prebuilt roles. You
can see nodepool actions on the Jenkins container::

 ssh -l root -A 192.168.134.53
 tail -f /var/log/nodepool/nodepool.log

Finally, you should see a Jenkins slave on Jenkins after some time. Now you're
ready to run test on your nodepool-managed Jenkins slaves!
