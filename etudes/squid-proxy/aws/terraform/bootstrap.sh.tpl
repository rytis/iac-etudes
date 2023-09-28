#!/bin/bash

set -e

export ANSIBLE_ROLES_PATH=/var/tmp/ansible/roles

/usr/local/bin/ansible-playbook /var/tmp/ansible/playbooks/bootstrap_server.yml
