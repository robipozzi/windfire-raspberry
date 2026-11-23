#!/bin/bash
# Configure the dashboard-managed Cloudflare Tunnel (cloudflared) on raspberry01 with cloudflare-tunnel.yaml
# The tunnel token is read only from the WINDFIRE_TUNNEL_TOKEN environment variable, for the one run that stores
# or rotates it (this script never asks for it, never prints it and never stores it):
#   read -rs WINDFIRE_TUNNEL_TOKEN                                                  paste from the password manager
#   WINDFIRE_TUNNEL_TOKEN="$WINDFIRE_TUNNEL_TOKEN" ./configure-cloudflare-tunnel.sh
#   unset WINDFIRE_TUNNEL_TOKEN
# Extra arguments are passed to ansible-playbook, e.g.
#   ./configure-cloudflare-tunnel.sh --check --diff                  dry run
#   ./configure-cloudflare-tunnel.sh -e cloudflared_start=true       also enable, (re)start and check the service
# Run from this script's folder, so ./setenv.sh and ansible.cfg are always this repo's. A bare
# "source setenv.sh" searches $PATH first and can load another project's setenv.sh.
cd "$(dirname "$0")" || exit 1
source ./setenv.sh

ANSIBLE_PLAYBOOK="cloudflare-tunnel.yaml"

echo "${cyn}==========================================================${end}"
echo "${cyn}  Raspberry PIs - Cloudflare Tunnel configuration ${end}"
echo "${cyn}==========================================================${end}"
if [ -n "${WINDFIRE_TUNNEL_TOKEN:-}" ]; then
  echo "${yel}WINDFIRE_TUNNEL_TOKEN is set: the tunnel token credential on raspberry01 will be replaced${end}"
else
  echo "${grn}WINDFIRE_TUNNEL_TOKEN is not set: the existing tunnel token credential is kept${end}"
fi
echo "${grn}Starting Ansible playbook: $ANSIBLE_PLAYBOOK $*${end}"

runWithAnsibleSshKey ansible-playbook $ANSIBLE_PLAYBOOK "$@"

EXIT_CODE=$?
if [ -n "${WINDFIRE_TUNNEL_TOKEN:-}" ]; then
  echo "${yel}Remember to run: unset WINDFIRE_TUNNEL_TOKEN${end}"
fi
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi
