#!/bin/bash
source setenv.sh

ANSIBLE_PLAYBOOK="raspberry.yaml"

echo "${cyn}=======================================${end}"
echo "${cyn}  Raspberry PIs - Common configuration ${end}"
echo "${cyn}=======================================${end}"
echo "${grn}Starting Ansible playbook: $ANSIBLE_PLAYBOOK${end}"

read -rsp "${yel}Enter Grafana Cloud API key : ${end}" GCLOUD_RW_API_KEY
echo

if [ -z "$GCLOUD_RW_API_KEY" ]; then
  echo "${red}ERROR: GCLOUD_RW_API_KEY cannot be empty${end}"
  exit 1
fi

ansible-playbook $ANSIBLE_PLAYBOOK --extra-vars "gcloud_rw_api_key=${GCLOUD_RW_API_KEY}"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi