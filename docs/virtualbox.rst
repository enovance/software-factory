.. toctree::

Using Virtualbox for testing SoftwareFactory
============================================

You can use Virtualbox if you want to try out Software Factory on your desktop.
First, you need to download one of our release images, for example 2.1.5::

 curl -O http://46.231.133.241:8080/v1/AUTH_sf/sf-images/softwarefactory-C7.0-2.1.5.img.qcow2

Next, increase the image size to ensure there is enough space is git and the
database and convert the image to make it usable with Virtualbox::

 qemu-img resize softwarefactory-C7.0-2.1.5.img.qcow2
 qemu-img convert -O vdi softwarefactory-C7.0-2.1.5.img.qcow2 softwarefactory-C7.0-2.1.5.vdi

Now you need to create a new VM in Virtualbox, and use the created .vdi file as
disk. Assign enough memory to it (2GB is a good starting point), and boot the VM.
Ensure you have at least one network interface besides the loopback interface
up; run "dhclient" for example.

Now you need to deploy SF. Run ``sfconfig.sh`` and wait a few minutes while the
system is prepared for you.

Finally, change the root password to make sure you can login afterwards.

Done! The webinterface is enabled on port 80, and the Gerrit git server on port
29418.

Happy testing!
