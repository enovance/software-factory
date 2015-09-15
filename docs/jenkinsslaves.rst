.. toctree::

Configure slave nodes for Jenkins
=================================

This section describes the methods to attach Jenkins slaves to the Jenkins master
we provide in SF.

Automatic setup via the Jenkins UI
----------------------------------

The easiest way is to start a VM and allow the Jenkins master to connect via
SSH on it. Indeed Jenkins is able to convert a minimal VM to a Jenkins slave.
Nevertheless the minimal VM needs some adjustments in order to let Jenkins
start the swarm process.

The instructions below are adapted to Centos 7 but should work on others Linux
distributions.

.. code-block:: bash

 $ sudo useradd -m jenkins
 $ sudo gpasswd -a jenkins wheel
 $ echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jenkins-slave
 $ echo "Defaults   !requiretty" | sudo tee --append /etc/sudoers.d/jenkins-slave
 $ chmod 0440 /etc/sudoers.d/jenkins-slave
 $ sudo mkdir /home/jenkins/.ssh
 $ sudo chown -R jenkins /home/jenkins/.ssh
 $ sudo chmod 700 /home/jenkins/.ssh
 $ sudo chmod 600 /home/jenkins/.ssh/authorized_keys

Then copy inside "/home/jenkins/.ssh/authorized_keys" the public key of Jenkins that you
can find in this file "/root/sf-bootstrap-data/ssh_keys/jenkins_rsa.pub" on the SF instance.

As the adminitrator, go in "Manage jenkins"/"Manage nodes"/"New node" and select
"Dumb node" plus add a node name. Keep the amount of executor to 1 if your jobs can't
run in paralllel. Set the "Remote root directory" to "/home/jenkins". Add the needed
label (your are going to use that label in the JJB descriptions of your jobs).
Keep "Launch slave agents on Unix machines via SSH" and the default credential
"jenkins (slave)" then enter the IP address of the VM you just created. Save, then
you should see the Slave appears in the Slave list.

Manual setup of a Jenkins slave
-------------------------------

You can follow the process below to configure manually a Jenkins slave.

You will need to substitute:

 - <sf-hostname>: the one you defined in sfconfig.yaml.
 - <jenkins-password>: The password of the Jenkins user. You can find it in
   "/root/sf-bootstrap-data/hiera/sfcreds.yaml" (creds_jenkins_user_password)

The instructions below are adapted to Centos 7 but should work on others Linux
distributions.

.. code-block:: bash

 $ sudo useradd -m jenkins
 $ sudo gpasswd -a jenkins wheel
 $ echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jenkins-slave
 $ echo "Defaults   !requiretty" | sudo tee --append /etc/sudoers.d/jenkins-slave
 $ chmod 0440 /etc/sudoers.d/jenkins-slave
 $ # Download and start the swarm client
 $ sudo -u jenkins curl -o /home/jenkins/swarm-client-1.22-jar-with-dependencies.jar \
    http://maven.jenkins-ci.org/content/repositories/releases/org/jenkins-ci/plugins/\
    swarm-client/1.22/swarm-client-1.22-jar-with-dependencies.jar
 $ sudo -u jenkins bash
 $ /usr/bin/java -Xmx256m -jar /home/jenkins/swarm-client-1.22-jar-with-dependencies.jar \
   -fsroot /home/jenkins -master http://<sf-hostname>:8080/jenkins -executors 1 -username jenkins -password \
   <jenkins-password> -name slave1 &> /home/jenkins/swarm.log &


You should check the swarm.log file to verify the slave is well connected to the jenkins master. You can
also check the Jenkins Web UI in order to verify the slave is listed in the slave list.

Then you can customize the slave node according to your needs to install components
required to run your tests.

If you want this slave authorizes jobs to be run concurrently then modify the "executors"
value.

Using nodepool to manage Jenkins slaves
---------------------------------------

NEED A REFRESH

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
