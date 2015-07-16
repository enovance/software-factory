#!/bin/bash

# Make sure the centos user can use the nodepool ssh key
echo "ssh-dss AAAAB3NzaC1kc3MAAACBAKR5MhCU7pP4O1XEPFM0mrz2O6xLShIW4nrOlSaj+emNFCqB/Dke43DCu1mZC+6MpNJVGa+IcMYQUptTEmYvtXMiVVTIZfOtagDlB8iXfHBAqYfOybAstnusMu39XeAg/lJWdpaiFBYVzMxgdFafdUSQDZtxolog1kbHhati/Nm7AAAAFQCloZ6vE4lN04fUmLlz+6VlQkiazwAAAIEAows4vjtT/5mR2HNBeBqHkY+EgzBtDaAKP7nXThzLwFHC78Xshi84EgbXBlnmclCESCeABamaSE8vMwGXupJsGlZpwVq0twz4sHKAxQhtx9PzYnAT3HaF9poobgVo0G+HFZUvD2NrKkF1iaqInEC+ilAGW2dcFXMGRC9U71WVnrwAAACAUzXPIpLJvxRTzW0JLp5oT2GTqRWvYs7d+USIXnRyj2Jp7pIb/hZ3LxAf6v8n5IqlQ47TtMI0mOi4XlCdT/n4zNJnSzPmopG69HRduv9TIaK7IlLYTZ3JYjF48r4Jt47Ua/cD85pXzNEnT7adW9Zz48yiuUoLmN7lDq+bZcEBb6w=" >> ~/.ssh/authorized_keys

# The jenkins user
sudo useradd -m jenkins
sudo mkdir /home/jenkins/.ssh
sudo cp /home/centos/.ssh/authorized_keys /home/jenkins/.ssh/authorized_keys
sudo chown jenkins /home/jenkins/.ssh
sudo chown jenkins /home/jenkins/.ssh/authorized_keys
sudo chmod 700 /home/jenkins/.ssh
sudo chmod 600 /home/jenkins/.ssh/authorized_keys

sudo restorecon -R -v /home/jenkins/.ssh/authorized_keys

# Required by Jenkins
sudo yum install -y java

# zuul-cloner is needed as well
sudo yum install -y epel-release
sudo yum install -y python-pip git python-devel gcc
sudo pip install zuul gitdb

# For testing using the local Gerrit instance. Needs to be accessible from the
# slave nodes, thus a public IP is required
echo '46.231.128.125 tests.dom' | sudo tee --append /etc/hosts

# sync FS, otherwise there are 0-byte sized files from the yum/pip installations
sudo sync
