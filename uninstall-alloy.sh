#!/bin/bash
# Run from this script's folder, so ./setenv.sh and ansible.cfg are always this repo's. A bare
# "source setenv.sh" searches $PATH first and can load another project's setenv.sh.
cd "$(dirname "$0")" || exit 1
source ./setenv.sh

ANSIBLE_PLAYBOOK="grafana/raspberry-alloy-uninstall.yaml"

echo "${cyn}=========================================================${end}"
echo "${cyn}  Raspberry PIs - Grafana Cloud Alloy uninstallation ${end}"
echo "${cyn}=========================================================${end}"
echo "${grn}Starting Ansible playbook: $ANSIBLE_PLAYBOOK${end}"

runWithAnsibleSshKey ansible-playbook $ANSIBLE_PLAYBOOK

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi