import os
from pecan.deploy import deploy

application = deploy('/var/lib/cauth/config.py')
