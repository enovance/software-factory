orig=$(pwd)
cd /var/lib/sf/roles/install/C7.0-0.9.2/install-server-vm
echo "Create install-server-vm archive"
tar -c --use-compress-program=pigz -f ../install-server-vm-C7.0-0.9.2.edeploy .
cd /var/lib/sf/roles/install/C7.0-0.9.2/softwarefactory
echo "Create softwarefactory archive"
tar -c --use-compress-program=pigz -f ../softwarefactory-C7.0-0.9.2.edeploy .
cd $orig
