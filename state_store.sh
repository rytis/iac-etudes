#!/bin/bash

set -e

if (( $# != 3 )); then
    echo "Usage: $0 <action> <cloud_provider> <etude>"
    echo ""
    echo "Where: action = (create|destroy)"
    exit 1
fi

ACTION=$1
CLOUD_PROVIDER=$2
ETUDE=$3

ansible-playbook ansible/playbooks/setup_state_store.yml -e "cloud_provider=${CLOUD_PROVIDER} etude=${ETUDE}"
