#!/bin/bash
# Run from this script's folder, so ./setenv.sh and ansible.cfg are always this repo's. A bare
# "source setenv.sh" searches $PATH first and can load another project's setenv.sh.
cd "$(dirname "$0")" || exit 1
source ./setenv.sh

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
# Read by the playbook with lookup('env', ...): not passed on the command line
export GCLOUD_RW_API_KEY

echo "${yel}WARNING: the playbook hardens SSH and sudo; keep an existing SSH session to each Pi open until the playbook's checks pass${end}"

runWithAnsibleSshKey ansible-playbook $ANSIBLE_PLAYBOOK

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi