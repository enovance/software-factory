Rename a project on SF
======================

Still a WIP:

- Zuul project.yaml renameing is missing

Add projects to rename there in rename-rules.yaml:

```YAML
repos:
- old: myproject
  new: mynewprojectname
```

Run:
ansible-playbook -i inventory rename_repos.yaml

Create that file before on the managesf node /root/.my.cnf

[client]
user=root
password=<from sfcreds.yaml>
