#!/bin/bash

set -e

export ANSIBLE_ROLES_PATH=/var/tmp/ansible/roles

%{ for var_name, var_val in ansible_cloud_init_env ~}
export ${upper(var_name)}="${var_val}"
%{ endfor ~}

ansible-playbook /var/tmp/ansible/playbooks/bootstrap-server.yml
