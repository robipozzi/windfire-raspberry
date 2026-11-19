#!/bin/bash
source setenv.sh

ANSIBLE_PLAYBOOK="raspberry-sw-prereqs.yaml"

echo "${cyn}======================================================${end}"
echo "${cyn}  Raspberry PIs - Software prerequisites installation ${end}"
echo "${cyn}======================================================${end}"
echo "${grn}Starting Ansible playbook: $ANSIBLE_PLAYBOOK${end}"

ansible-playbook $ANSIBLE_PLAYBOOK

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi