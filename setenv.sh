##### Terminal Colors - START
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'
coffee=$'\xE2\x98\x95'
coffee3="${coffee} ${coffee} ${coffee}"
##### Terminal Colors - END

###### Ansible SSH key - START
ANSIBLE_SSH_KEY=$HOME/.ssh/ansible_rsa

# ===== ANSIBLE SSH KEY =====
# Run a command (normally ansible-playbook) with ANSIBLE_SSH_KEY loaded in a private ssh-agent,
# stopped when the command ends. Every script that runs Ansible goes through this function.
# On macOS, Apple's ssh-add saves the key passphrase in the login Keychain on the first run and
# reads it from there afterwards, so it is asked only once. Elsewhere it is asked on every run.
# Usage: runWithAnsibleSshKey ansible-playbook <playbook> [args...]
runWithAnsibleSshKey()
{
    (
        eval "$(ssh-agent -s)" >/dev/null || exit 1
        trap 'ssh-agent -k >/dev/null' EXIT
        if [[ "$(uname -s)" == "Darwin" && -x /usr/bin/ssh-add ]]; then
            /usr/bin/ssh-add --apple-use-keychain "$ANSIBLE_SSH_KEY" \
                || { echo "ssh-add --apple-use-keychain failed, retrying without the Keychain" >&2; ssh-add "$ANSIBLE_SSH_KEY"; }
        else
            ssh-add "$ANSIBLE_SSH_KEY"
        fi || { echo "Error: ssh-add $ANSIBLE_SSH_KEY failed" >&2; exit 1; }
        "$@"
    )
}
###### Ansible SSH key - END
