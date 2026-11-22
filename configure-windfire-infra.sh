#!/bin/bash
# Configure the Windfire infrastructure on the Raspberry PIs: UFW rules, the shared Windfire CA certificates
# (/etc/windfire/ca) and per-service software
# Extra arguments are passed to ansible-playbook, e.g.
#   ./configure-windfire-infra.sh --check --diff
#   ./configure-windfire-infra.sh --tags windfire_ca                                    install or rotate the CA certificates
#   ./configure-windfire-infra.sh --tags windfire_ca -e windfire_ca_remove_legacy=true  also delete the old CA copies
# Tags: ufw, windfire_ca, java
source setenv.sh

ANSIBLE_PLAYBOOK="raspberry-configure-windfire-infra.yaml"

echo "${cyn}==========================================================${end}"
echo "${cyn}  Raspberry PIs - Windfire infrastructure configuration ${end}"
echo "${cyn}==========================================================${end}"
echo "${grn}Starting Ansible playbook: $ANSIBLE_PLAYBOOK $*${end}"

runWithAnsibleSshKey ansible-playbook $ANSIBLE_PLAYBOOK "$@"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi
