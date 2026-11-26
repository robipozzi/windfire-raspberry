#!/bin/bash
# Configure the dashboard-managed Cloudflare Tunnel (cloudflared) on raspberry01 with cloudflare-tunnel.yaml
# The script asks for the tunnel token at the terminal (input not echoed): paste it from the password manager to
# store or rotate the credential, or press Enter to keep the existing one. The token lives only in a non-exported
# variable of this script's process and is handed to ansible-playbook alone, through its environment (never on a
# command line); it disappears when the script ends, so there is nothing to unset and nothing reaches shell history.
# The script never prints the token and never stores it.
# Non-interactive runs (stdin not a terminal) do not prompt; WINDFIRE_TUNNEL_TOKEN, if already set in the
# environment, is still accepted instead of the prompt.
# Extra arguments are passed to ansible-playbook, e.g.
#   ./configure-cloudflare-tunnel.sh --check --diff                  dry run
#   ./configure-cloudflare-tunnel.sh -e cloudflared_start=true       also enable, (re)start and check the service
set +x  # an inherited xtrace must never echo the token
# Run from this script's folder, so ./setenv.sh and ansible.cfg are always this repo's. A bare
# "source setenv.sh" searches $PATH first and can load another project's setenv.sh.
cd "$(dirname "$0")" || exit 1
source ./setenv.sh

ANSIBLE_PLAYBOOK="cloudflare-tunnel.yaml"

echo "${cyn}==========================================================${end}"
echo "${cyn}  Raspberry PIs - Cloudflare Tunnel configuration ${end}"
echo "${cyn}==========================================================${end}"

# ===== TUNNEL TOKEN =====
# Kept in a non-exported variable: ssh-agent, ssh-add and every other child process never see it.
tunnel_token=""
trap 'unset tunnel_token' EXIT INT TERM
if [ -n "${WINDFIRE_TUNNEL_TOKEN:-}" ]; then
  tunnel_token="$WINDFIRE_TUNNEL_TOKEN"
  unset WINDFIRE_TUNNEL_TOKEN
elif [ -t 0 ]; then
  read -rsp "${yel}Cloudflare tunnel token (Enter = keep the existing credential): ${end}" tunnel_token
  echo
fi
# Pasting from a password manager can add spaces, newlines or a CR: a tunnel token has none
tunnel_token="${tunnel_token//[[:space:]]/}"
if [ -n "$tunnel_token" ]; then
  if [[ "$tunnel_token" != eyJ* ]]; then
    echo "${yel}Warning: this does not look like a Cloudflare tunnel token (expected to start with eyJ)${end}"
  fi
  echo "${yel}Tunnel token provided: the tunnel token credential on raspberry01 will be replaced${end}"
else
  echo "${grn}No tunnel token provided: the existing tunnel token credential is kept${end}"
fi

# Run ansible-playbook with WINDFIRE_TUNNEL_TOKEN in its environment only (a prefix assignment, not "env VAR=..."
# which would put the value on a command line visible in ps, and not "export" which would leak it to every child)
runPlaybook()
{
  if [ -n "$tunnel_token" ]; then
    WINDFIRE_TUNNEL_TOKEN="$tunnel_token" ansible-playbook "$@"
  else
    ansible-playbook "$@"
  fi
}

echo "${grn}Starting Ansible playbook: $ANSIBLE_PLAYBOOK $*${end}"

runWithAnsibleSshKey runPlaybook "$ANSIBLE_PLAYBOOK" "$@"

EXIT_CODE=$?
unset tunnel_token
if [ $EXIT_CODE -eq 0 ]; then
  echo "${grn}Playbook completed successfully ${coffee}${end}"
else
  echo "${red}Playbook failed with exit code ${EXIT_CODE}${end}"
  exit $EXIT_CODE
fi
