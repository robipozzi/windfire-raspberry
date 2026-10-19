# Raspberry Pi base settings in windfire-raspberry

## Context
All Raspberry Pi boxes should share the same secure baseline: ufw, chrony, the step CLI, automatic security updates, a hardened `pi` admin account and hardened SSH. Today [raspberry.yaml](windfire-raspberry/raspberry.yaml) only updates/upgrades apt, installs openssl and Grafana Alloy (all in `pre_tasks`, no `tasks`). raspberry01/02 were hardened by hand: sudo already needs pi's password, and `ansible.cfg` sets `become_ask_pass=True`. The playbook should reproduce that on any box and check it.

Decisions taken:
- **step**: install `step-cli` only (no CA server; the CA stays on raspberry01:9443). The Windfire Root CA is **not** added to the system trust store: the apps already ship their own copy (`windfire_ca_root_certificate` / `ROOT_CA_PATH`) and nothing else needs it.
- **ufw**: install the package only. Don't change or enable rules, so the hand-made rules on raspberry01/02 stay as they are.

Repo: `/Users/robertopozzi/dev/windfire-raspberry`, branch `feature/update-ansible-pi-install` (clean).

## Changes

### 1. `raspberry.yaml`: new sections in `tasks:` (after the existing `pre_tasks`)
Use the existing `##### X Section #####` banner style. Add a `handlers:` block.

1. **UFW Section**: `apt: name=ufw state=present`. Nothing else.
2. **Chrony Section**: install `chrony` with apt (the package conflict removes `systemd-timesyncd`). Then `service: name=chrony state=started enabled=yes`.
3. **Step CLI Section**
   - Get the Smallstep apt key `https://packages.smallstep.com/keys/apt/repo-signing-key.gpg` into `/etc/apt/keyrings/smallstep.asc` (`get_url`).
   - Add the repo with `apt_repository`: `deb [signed-by=/etc/apt/keyrings/smallstep.asc] https://packages.smallstep.com/stable/debian debs main` (filename `smallstep`).
   - Install `step-cli` with apt.
4. **Automatic security updates Section**
   - Install `unattended-upgrades`, `apt-listchanges` and `needrestart` with apt.
   - Template `/etc/apt/apt.conf.d/20auto-upgrades` with `APT::Periodic::Update-Package-Lists "1";` and `APT::Periodic::Unattended-Upgrade "1";`. This is the non-interactive version of `dpkg-reconfigure -plow unattended-upgrades`.
   - Use `lineinfile` on `/etc/apt/apt.conf.d/50unattended-upgrades`, `insertafter: '^Unattended-Upgrade::Origins-Pattern \{'`. Add the line `"origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";`. `${...}` isn't Jinja, so it's written literally.
   - Put `$nrconf{restart} = 'a';` in `/etc/needrestart/conf.d/50-autorestart.conf` so needrestart never waits for input during unattended or Ansible runs.
5. **Harden pi admin Section** (runs before SSH hardening, as safety gates)
   - `stat /home/pi/.ssh/authorized_keys`, then `assert` that it exists and isn't empty. This stops the run before passwords are turned off on a box with no key.
   - `passwd -S pi`, then `assert` that the status is `P` (usable password, which sudo needs).
   - Remove `/etc/sudoers.d/010_pi-nopasswd` (`file state=absent`). Then `grep -rE 'NOPASSWD' /etc/sudoers /etc/sudoers.d` and `assert` that pi doesn't match, so sudo always asks for a password.
   - No personal user is created.
6. **SSH hardening Section**
   - Copy `/etc/ssh/sshd_config.d/10-hardening.conf` (root, 0644) with the 5 settings from the request. sshd uses the first value it reads, so `10-` wins over Raspberry Pi OS's `50-cloud-init.conf`.
   - Validate with `/usr/sbin/sshd -t`. Notify the `reload ssh` handler (`systemctl reload ssh`). A reload doesn't drop the Ansible session that's already open.
7. **Baseline checks** (in `post_tasks`, after `meta: flush_handlers`)
   - `chronyc tracking`: assert `Leap status     : Normal`, then `debug` the `System time` line for each host so you can compare offsets between boxes.
   - `unattended-upgrade --dry-run --debug 2>&1 | grep -i 'allowed origins'`: assert it contains `Debian-Security` and `Raspberry Pi Foundation`.
   - `sshd -T`: assert `passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin no`, `pubkeyauthentication yes`, `allowusers pi`.
   - Local password test (`delegate_to: localhost`, `become: no`): `ssh -o PubkeyAuthentication=no -o BatchMode=yes -o StrictHostKeyChecking=accept-new pi@{{ inventory_hostname }} true`. Expect it to fail and stderr to contain `Permission denied (publickey)`. A normal login is already proven, because the play itself connected over the key.

Keep the Alloy include as it is in `pre_tasks`.

### 2. ~~New file `conf/ca/WindfireRootCA.crt`~~
Dropped: the Root CA is not added to the system trust store (see Decisions taken).

### 3. `install.sh`
Before running the playbook, print a yellow warning: "keep an existing SSH session to each Pi open until the playbook's checks pass". `-K` already comes from `become_ask_pass=True` in `ansible.cfg`, so nothing else changes.

### 4. `README.md`
Extend the "Installation automation task" bullet list with the new baseline (ufw installed, chrony, step-cli, unattended security upgrades with the RPi origin, pi/sudo hardening, SSH hardening), the checks the playbook runs, and the "keep session open" advice.

### 5. Memory
After the change, update `raspberry-hardened-sudo.md` to say windfire-raspberry now enforces the baseline.

## Verification
1. `ansible-playbook raspberry.yaml --syntax-check` and `ansible-lint raspberry.yaml` if it's installed.
2. Open an SSH session to raspberry01 and keep it open. Run `./install.sh` (asks for the Grafana key, then the BECOME password). All `post_tasks` assertions must pass on raspberry01 and raspberry02.
3. By hand, from a new terminal: `ssh -o PubkeyAuthentication=no pi@raspberry01` fails with `Permission denied (publickey)`. `ssh pi@raspberry01` works, and `sudo -k; sudo true` asks for a password.
4. On each box, `chronyc tracking` shows a System time offset of a few ms. `sudo ufw status` is unchanged from before.
5. Run the playbook a second time to check it's idempotent (no `changed` in the hardening sections).
