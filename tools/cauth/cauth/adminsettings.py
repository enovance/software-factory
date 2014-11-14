# This file is only an example, contents will be overwritten by Puppet
username = "user1"
# You need to enter a hashed password here. To create one, use the following
# Python code:
#
# import hashlib, uuid
# salt = uuid.uuid4().hex
# print salt + "#" + hashlib.sha512("new_password" + salt).hexdigest()'
#
password = "REPLACE_THIS_WITH_A_SALTED_HASH"
mail = "user1@example.com"
lastname = "Admin user"
