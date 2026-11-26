#!/bin/bash
# Switch Windfire between public access through the Cloudflare Tunnel and LAN-only access (home WiFi), or report
# which mode it is in. Nothing on Cloudflare's side is changed (tunnel, routes, DNS, Access stay as they are), and the
# Keycloak UI client keeps its https://app.<domain> entries, so both directions need no dashboard or console work.
#
#   ./switch-windfire-exposure.sh status                   read-only: LAN, PUBLIC or MIXED (exit 1 on MIXED)
#   ./switch-windfire-exposure.sh lan [-y] [--forget-token]
#   ./switch-windfire-exposure.sh public [-y]
#
# lan:    1. windfire-exposure.yaml prepare: stop and disable cloudflared (internet access ends here), record the mode
#            on both Pis, set KEYCLOAK_ISSUER_URL of windfire-security and windfire-restaurants-backend, restart them
#         2. windfire-security keycloak/deployment/deploy-keycloak-tls.sh with keycloak_public_url = internal URL
#         3. windfire-ui-react deployment/deploy.sh 1 --profile lan
#         4. windfire-exposure.yaml status: must print LAN
# public: 1. prepare (mode, issuers), 2. Keycloak with the public URL, 3. UI --profile public,
#         4. windfire-exposure.yaml tunnel: enable and start cloudflared last, once everything else is public,
#         5. status: must print PUBLIC
#
# --forget-token (lan only) also shreds the encrypted tunnel token credential on raspberry01: going public again then
# needs ./configure-cloudflare-tunnel.sh -e cloudflared_start=true and the token from the password manager.
#
# From step 1 to the end nobody can sign in, and afterwards everyone signs in again (tokens carry the old issuer).
# Every step is idempotent: if one fails, fix the cause and run the same command again.
# Each step asks for the pi sudo password (BECOME password); going public, the Keycloak step may also ask for the
# Keycloak master admin credentials and an OTP code; the UI step asks its usual questions (press Enter for the
# profile's defaults).
#
# The sibling repositories are expected next to this one; override with WINDFIRE_SECURITY_DIR / WINDFIRE_UI_DIR.
cd "$(dirname "$0")" || exit 1
source ./setenv.sh

ANSIBLE_PLAYBOOK="windfire-exposure.yaml"
CONFIG_FILE="conf/config.yml"
WINDFIRE_SECURITY_DIR=${WINDFIRE_SECURITY_DIR:-$(cd .. && pwd)/windfire-security}
WINDFIRE_UI_DIR=${WINDFIRE_UI_DIR:-$(cd .. && pwd)/windfire-ui-react}

usage()
{
  echo "Usage: $0 status | lan [-y] [--forget-token] | public [-y]"
}

# Value of a top-level "key: value" line of conf/config.yml (quotes removed)
configValue()
{
  sed -n "s/^$1: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p" "$CONFIG_FILE"
}

runPlaybook()
{
  runWithAnsibleSshKey ansible-playbook "$ANSIBLE_PLAYBOOK" "$@"
}

stepFailed()
{
  echo "${red}Step '$1' failed: Windfire is half switched. Fix the cause above and run $0 $TARGET again${end}" >&2
  exit 1
}

TARGET=
ASSUME_YES=false
FORGET_TOKEN=false
while [[ $# -gt 0 ]]; do
  case $1 in
    lan|public|status) TARGET=$1 ;;
    -y|--yes) ASSUME_YES=true ;;
    --forget-token) FORGET_TOKEN=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "${red}Unknown argument: $1${end}" >&2; usage >&2; exit 1 ;;
  esac
  shift
done
if [[ -z "$TARGET" ]]; then
  usage >&2
  exit 1
fi
if [[ "$FORGET_TOKEN" == true && "$TARGET" != lan ]]; then
  echo "${red}--forget-token only goes with lan${end}" >&2
  exit 1
fi

echo "${cyn}==========================================================${end}"
echo "${cyn}  Windfire exposure: ${TARGET} ${end}"
echo "${cyn}==========================================================${end}"

if [[ "$TARGET" == status ]]; then
  runPlaybook -e windfire_exposure_step=status
  exit $?
fi

# ===== PRE-FLIGHT =====
PUBLIC_URL=$(configValue windfire_public_keycloak_url)
INTERNAL_URL=$(configValue windfire_internal_keycloak_url)
if [[ -z "$PUBLIC_URL" || -z "$INTERNAL_URL" ]]; then
  echo "${red}windfire_public_keycloak_url / windfire_internal_keycloak_url not found in $CONFIG_FILE${end}" >&2
  exit 1
fi
if [[ "$TARGET" == public ]]; then KEYCLOAK_URL=$PUBLIC_URL; else KEYCLOAK_URL=$INTERNAL_URL; fi
KEYCLOAK_TLS_DEPLOY="$WINDFIRE_SECURITY_DIR/keycloak/deployment/deploy-keycloak-tls.sh"
UI_DEPLOY="$WINDFIRE_UI_DIR/deployment/deploy.sh"
for script in "$KEYCLOAK_TLS_DEPLOY" "$UI_DEPLOY"; do
  if [[ ! -f "$script" ]]; then
    echo "${red}$script not found: clone the repository next to this one, or set WINDFIRE_SECURITY_DIR / WINDFIRE_UI_DIR${end}" >&2
    exit 1
  fi
done
# The switch itself works without it, but a later deploy from a repository that does not read the recorded mode
# would put the other issuer back
for check in "$WINDFIRE_SECURITY_DIR/keycloak/deployment/raspberry/conf/keycloak-tls-config.yml" \
             "$WINDFIRE_SECURITY_DIR/deployment/raspberry/windfire-security-deploy.yaml" \
             "$WINDFIRE_UI_DIR/deployment/raspberry/tasks/deploy-app.yaml"; do
  if ! grep -q 'ansible_local' "$check" 2>/dev/null; then
    echo "${yel}Warning: $check does not read the recorded mode yet (pull its main branch):${end}"
    echo "${yel}         until then, a regular deploy of that repository can put the other issuer back${end}"
  fi
done

echo "Target mode:        ${mag}${TARGET}${end}"
echo "Keycloak / issuer:  ${mag}${KEYCLOAK_URL}${end}"
if [[ "$TARGET" == lan ]]; then
  echo "Cloudflare Tunnel:  ${mag}stopped and disabled first${end} (token credential $([[ "$FORGET_TOKEN" == true ]] && echo "${red}deleted${end}" || echo kept))"
  echo "Browsers:           https://raspberry01:8445 on the home network only"
else
  echo "Cloudflare Tunnel:  ${mag}enabled and started last${end}"
  echo "Browsers:           https://app.windfire.cc (through Cloudflare Access)"
fi
echo "Cloudflare dashboard and the Keycloak UI client are not changed."
echo "${yel}Nobody can sign in until the switch is over, and everyone signs in again afterwards.${end}"
if [[ "$ASSUME_YES" != true ]]; then
  read -r -p "${yel}Switch Windfire to ${TARGET}? [y/N] ${end}" answer
  [[ "$answer" =~ ^[yY]$ ]] || { echo "Nothing changed"; exit 0; }
fi

EXTRA_ARGS=(-e "windfire_exposure=$TARGET")
[[ "$FORGET_TOKEN" == true ]] && EXTRA_ARGS+=(-e windfire_forget_tunnel_token=true)

# ===== SWITCH =====
echo "${grn}[1] Tunnel, recorded mode and service issuers ($ANSIBLE_PLAYBOOK, step prepare)${end}"
runPlaybook "${EXTRA_ARGS[@]}" -e windfire_exposure_step=prepare || stepFailed prepare

echo "${grn}[2] Keycloak hostname $KEYCLOAK_URL (windfire-security deploy-keycloak-tls.sh)${end}"
bash "$KEYCLOAK_TLS_DEPLOY" -e "keycloak_public_url=$KEYCLOAK_URL" || stepFailed keycloak

echo "${grn}[3] UI with the $TARGET profile (windfire-ui-react deploy.sh): press Enter to keep the profile's defaults${end}"
bash "$UI_DEPLOY" 1 --profile "$TARGET" || stepFailed ui

if [[ "$TARGET" == public ]]; then
  echo "${grn}[4] Cloudflare Tunnel ($ANSIBLE_PLAYBOOK, step tunnel)${end}"
  runPlaybook "${EXTRA_ARGS[@]}" -e windfire_exposure_step=tunnel || stepFailed tunnel
fi

echo "${grn}[$([[ "$TARGET" == public ]] && echo 5 || echo 4)] Check ($ANSIBLE_PLAYBOOK, step status)${end}"
runPlaybook -e "windfire_exposure=$TARGET" -e windfire_exposure_step=status || stepFailed status

echo "${grn}Windfire is ${TARGET} ${coffee}${end}"
if [[ "$TARGET" == lan ]]; then
  echo "Sign in at https://raspberry01:8445 from the home network. A phone on mobile data must not reach Windfire."
else
  echo "Sign in at https://app.windfire.cc, and check from a phone on mobile data."
fi
