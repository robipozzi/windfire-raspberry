#!/bin/bash
cd "$(dirname "$0")" || exit 1
source ../setenv.sh
runWithAnsibleSshKey ansible-playbook raspberry-docker-uninstall.yaml
