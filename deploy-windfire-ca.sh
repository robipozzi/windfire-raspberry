#!/bin/bash
# Install (or rotate) the Windfire CA certificates in the shared, root-owned /etc/windfire/ca folder on every
# Raspberry PI box, from the admin laptop's truststores. See "Windfire CA certificates" in README.md.
# Usage: ./deploy-windfire-ca.sh [--check] [--remove-legacy] [-y] [extra ansible-playbook arguments]
cd "$(dirname "$0")" || exit 1
source setenv.sh

ANSIBLE_PLAYBOOK="windfire-ca.yaml"

printHelp()
{
  echo "Usage: ./deploy-windfire-ca.sh [--check] [--remove-legacy] [-y] [extra ansible-playbook arguments]"
  echo
  echo "Installs WindfireRootCA.crt and WindfireKeycloakRootCA.crt in /etc/windfire/ca (root:root, 0755 folder,"
  echo "0644 certificates) on every Raspberry PI box, from ~/opt/windfire/ssl/truststore and ~/opt/keycloak/ssl/truststore."
  echo
  echo "  --check           dry run (ansible-playbook --check --diff): nothing is changed on the boxes"
  echo "  --remove-legacy   also delete the old CA copies under /home/pi/opt, once no service references a CA"
  echo "                    outside /etc/windfire/ca (redeploy every service first)"
  echo "  -y                do not ask for confirmation before --remove-legacy"
  echo "  -h, --help        show this help"
  echo
  echo "Any other argument is passed to ansible-playbook. The BECOME password is the sudo password of user pi."
}

ANSIBLE_ARGS=()
REMOVE_LEGACY=false
ASSUME_YES=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      printHelp
      exit 0
      ;;
    --check)
      ANSIBLE_ARGS+=(--check --diff)
      ;;
    --remove-legacy)
      REMOVE_LEGACY=true
      ;;
    -y)
      ASSUME_YES=true
      ;;
    *)
      ANSIBLE_ARGS+=("$1")
      ;;
  esac
  shift
done

if [ "$REMOVE_LEGACY" = true ]; then
  if [ "$ASSUME_YES" != true ]; then
    read -r -p "${yel}This deletes the CA copies under /home/pi/opt on every Pi. Continue? [y/N]: ${end}" answer
    case $answer in
      y|Y|yes|YES) ;;
      *) echo "${cyn}Cancelled${end}"
         exit 0
         ;;
    esac
  fi
  ANSIBLE_ARGS+=(-e windfire_ca_remove_legacy=true)
fi

echo "${cyn}==========================================================${end}"
echo "${cyn}  Raspberry PIs - Windfire CA certificates (/etc/windfire/ca) ${end}"
echo "${cyn}==========================================================${end}"
echo "${grn}Starting Ansible playbook: $ANSIBLE_PLAYBOOK ${ANSIBLE_ARGS[*]}${end}"

ansible-playbook "$ANSIBLE_PLAYBOOK" "${ANSIBLE_ARGS[@]}"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi
