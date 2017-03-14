This playbook is used to prepare a pre upgrade environment duplicating
the production environment

# example for preprod

openstack volume create --source c854c6c1-07b7-41e0-9f3e-15f4bfde42df --size 20 managesf.preprod.softwarefactory-project.io


# manually create snapshot
openstack snapshot create --name managesf.preprod.softwarefactory-project.io managesf.preprod.softwarefactory-project.io

openstack volume create --source managesf.preprod.softwarefactory-project.io --size 20 current-managesf.preprod.softwarefactory-project.io
openstack server create --flavor 2 --volume current-managesf.preprod.softwarefactory-project.io --security-group sf-pre-upgrade managesf.preprod.softwarefactory-project.io
