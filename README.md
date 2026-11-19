# Raspberry Pi automation
[![CI](https://github.com/robipozzi/windfire-raspberry/actions/workflows/ci.yml/badge.svg)](https://github.com/robipozzi/windfire-raspberry/actions/workflows/ci.yml)

- [Introduction](#introduction)
- [Ansible configuration setup](#Ansible-configuration-setup)
- [Installation automation task](#Installation-automation-task)
    - [Grafana Cloud configuration](#Grafana-Cloud-configuration)
    - [Windfire infrastructure configuration automation task](#Windfire-infrastructure-configuration-automation-task)
        - [UFW rules as code](#UFW-rules-as-code)
    - [Basic web infrastructure installation automation task](#Basic-web-infrastructure-installation-automation-task)
    - [Docker installation automation task](#Docker-installation-automation-task)
- [CI and dependency monitoring](#CI-and-dependency-monitoring)
- [Projects](#projects)
    - [Home Automation](#home-automation)
- [References](#References)

## Introduction
This repository holds scripts, playbooks and configurations to automate infrastructure configuration tasks on Raspberry Pi boards.

## Ansible configuration setup
The scripts provided are based on Ansible technology (https://www.ansible.com/) for task automation; refer to Ansible technical 
documentation (https://docs.ansible.com/) for detailed instructions regarding installation and setup.

Ansible uses ssh to connect to the managed infrastructure, so you will first need to generate an ssh key pair; the script *[ansible-initialize.sh](ansible-initialize.sh)*, provided in the root folder of this repo, copies the public ssh key to a remote destination (you will need to pass it as a parameter when you launch the script), assuming you generated a key called *ansible_rsa* and saved it in *.ssh* sub-folder under your user home directory.

A file, named *[ansible.cfg](ansible.cfg)*, is also provided to set basic configurations needed to run Ansible; if you launch Ansible from the repo root directory, this file will be read and used as the source for configuration settings (unless you have set an ANSIBLE_CONFIG environment variable, which has precedence), the basic configuration you should have is something like this:

![](images/ansible-config.png)
where:

* *inventory* defines where Ansible will look for the inventory file, which is used by Ansible to know which servers to connect and manage.
* *private_key_file* points to the SSH private key you have previously generated, used by Ansible to connect and launch tasks on the target Raspberry Pi;

Change the parameters according to your environment.

## Installation automation task
The **[raspberry.yaml](raspberry.yaml)** playbook is provided to do the following basic tasks on all Raspberry boxes consistently:

    * update package manager repo cache and upgrade installed packages on all Raspberry Pi boxes
    * install OpenSSL on all Raspberry Pi boxes
    * install and configure Grafana Cloud Alloy, which ships to Grafana Cloud (see [Grafana Cloud configuration](#Grafana-Cloud-configuration)):
        * node metrics; the systemd collector reports only the keycloak, alloy and windfire-* units
        * only the systemd journal of the units listed in *alloy_journal_units* and the kernel "[UFW BLOCK]" lines; /var/log is not read
        * lines that look like they hold a secret (password, passwd, secret, token, authorization, api_key / api-key / apikey, client_secret, any case) are dropped before they leave the Pi
    * install UFW and allow SSH (22/tcp) from the admin laptop (*admin_ip*); on a new Pi (UFW not active) also set default deny incoming / allow outgoing and enable UFW, so only SSH from the laptop gets in; on a Pi where UFW is already active the other rules and the defaults are not changed
    * install Chrony for time synchronization (it replaces systemd-timesyncd)
    * install the Smallstep step CLI (step-cli) from the Smallstep apt repository
    * enable unattended security upgrades, also allowing the Raspberry Pi Foundation origin, with needrestart set to restart services automatically
    * harden the pi admin account: sudo always asks for pi's password (passwordless sudo rule removed)
    * harden SSH (/etc/ssh/sshd_config.d/10-hardening.conf): key-only login, no root login, only pi allowed

UFW is enabled only when the playbook runs from *admin_ip*, otherwise it stops before enabling it; note that a Pi where UFW was deliberately disabled counts as new, so UFW gets enabled there too.
Before changing pi and SSH, the playbook stops if pi has no (or an empty) *authorized_keys* file or no usable password, so a box cannot be locked out.
At the end it checks the result on every box:

    * Chrony is synchronized (and shows the System time offset of each box)
    * unattended-upgrades allows the Debian-Security and Raspberry Pi Foundation origins
    * UFW is active, denies incoming traffic by default and allows SSH from *admin_ip*
    * the effective sshd configuration (sshd -T) is hardened
    * a password login from the control machine is refused with "Permission denied (publickey)"

**Keep an existing SSH session to each Pi open until the playbook's checks pass**, so you can fix things if something goes wrong.
Sudo on the Pis needs pi's password: Ansible asks for it once per run (BECOME password, *become_ask_pass* in *[ansible.cfg](ansible.cfg)*).

A convenient scripts **[install.sh](install.sh)** is provided, using *[raspberry.yaml](raspberry.yaml)* playbook to consistently configure Raspberry Pi boxes.

Playbook refers to **[config.yml](conf/config.yml)** yaml file provided in *[conf](conf)* sub-folder for common variables setup and usage, and to *conf/grafana.yml* for the Grafana Cloud details (see below).

### Grafana Cloud configuration
The Grafana Cloud URLs and usernames are not stored in the repository. Before the first run:

1. copy *[conf/grafana.yml_PLACEHOLDER](conf/grafana.yml_PLACEHOLDER)* to *conf/grafana.yml*: `cp conf/grafana.yml_PLACEHOLDER conf/grafana.yml`
2. replace the dummy values with the details of your Grafana Cloud stack (grafana.com > My Account > your stack > Details):

| Variable | Value |
|---|---|
| *grafana_fleet_url*, *grafana_fleet_user* | Fleet Management URL and username (Alloy *remotecfg*) |
| *grafana_prom_url*, *grafana_prom_user* | Prometheus remote write URL (ending in /api/prom/push) and username |
| *grafana_loki_url*, *grafana_loki_user* | Loki push URL (ending in /loki/api/v1/push) and username |

*conf/grafana.yml* is in *[.gitignore](.gitignore)*: never commit it. The playbook stops before touching any Pi if the file is missing.

The Grafana Cloud API key is read from the *GCLOUD_RW_API_KEY* environment variable, never from the command line: *[install.sh](install.sh)* asks for it and exports it; if you run `ansible-playbook raspberry.yaml` directly, run `read -rs GCLOUD_RW_API_KEY && export GCLOUD_RW_API_KEY` first. The playbook stops if the variable is empty.

Logs shipped by Alloy:

* the systemd journal of the units listed in *alloy_journal_units* in *[config.yml](conf/config.yml)* (keycloak, windfire-security, windfire-calendar, windfire-restaurants-backend, windfire-ui-react, ssh and unattended-upgrades by default); to ship another unit, add its name (e.g. *myapp.service*) to the list and run the playbook again
* kernel lines that contain "[UFW BLOCK]" (connections blocked by UFW); other kernel lines are dropped
* nothing from /var/log: the journal already holds those messages

The first stage drops any line matching `(?i)(password|passwd|secret|token|authorization|api[_-]?key|client_secret)`; then kernel lines without "[UFW BLOCK]" are dropped. Dropped lines are counted by Alloy in the *loki_process_dropped_lines_total* metric, with *reason* "sensitive_content" (secret-looking lines) or "kernel_not_ufw_block" (other kernel lines); check it on the Pi with `curl -s localhost:12345/metrics | grep loki_process_dropped_lines_total`.

### Firewall and SSH lockout recovery
The UFW rules rely on the DHCP reservations of these IPs on the home router (variables in *[config.yml](conf/config.yml)*):

| Variable | Host | IP |
|---|---|---|
| *admin_ip* | admin laptop | 192.168.1.27 |
| *raspberry01_ip* | raspberry01 | 192.168.1.18 |
| *raspberry02_ip* | raspberry02 | 192.168.1.2 |
| *pi_core_ip* | pi-core | 192.168.1.10 |

*admin_ip*, *raspberry02_ip* and *pi_core_ip* are used by the per-host rules in *ufw_rules* (see [UFW rules as code](#UFW-rules-as-code)); *raspberry01_ip* is not used by a rule yet, it is recorded for rules that will be set in the future.

If a reservation is lost or changed (e.g. the laptop gets a different IP), SSH from the laptop is blocked: restore the reservation, or update the variables and run the playbooks again (*[install.sh](install.sh)*, then *[configure-windfire-infra.sh](configure-windfire-infra.sh)*).

If SSH is locked out:

1. connect a monitor and keyboard to the Pi and log in as *pi* on the local console
2. run `sudo ufw disable`
3. fix the IP reservation, or allow the new IP: `sudo ufw allow from <ip> to any port 22 proto tcp comment 'SSH from admin laptop'`
4. run `sudo ufw enable` and, before logging out of the console, check from a new SSH session that you can log in (`sudo ufw status verbose` shows the rules)

### Windfire infrastructure configuration automation task
Once Raspberry Pi boxes are installed and configured with the common basic software stack (*[raspberry.yaml](raspberry.yaml)*), the Windfire infrastructure is configured on top of it: the UFW rules of each box and, for each specific box (e.g.: *appserver*, *calendar_service*, ...), a specific software stack.
<!-- windfire-maps retired (F20): the maps_service example above was
     (e.g.: *appserver*, *maps_service*, *calendar_service*, ...) -->

The **[raspberry-configure-windfire-infra.yaml](raspberry-configure-windfire-infra.yaml)** playbook is provided to do the following tasks on specific Raspberry boxes consistently:

    * ensure the UFW rules listed for each box in ufw_rules (see UFW rules as code below)
    * install OpenJDK on all appserver Raspberry Pi boxes

<!-- windfire-maps retired (F20): the maps_service play is commented out in the playbook
    * install NodeJS, npm and pm2 on all maps_service Raspberry Pi boxes
-->

A convenient script **[configure-windfire-infra.sh](configure-windfire-infra.sh)** is provided, using *[raspberry-configure-windfire-infra.yaml](raspberry-configure-windfire-infra.yaml)* playbook to consistently configure the Windfire infrastructure on the Raspberry Pi boxes; any extra argument is passed to *ansible-playbook* (e.g. `--check --diff`, `-e ufw_prune_unlisted=true`).

Run *[install.sh](install.sh)* (*[raspberry.yaml](raspberry.yaml)*) first: the UFW play stops on a box where UFW is not active.

#### UFW rules as code
The UFW rules of each box are listed in *ufw_rules* in *[config.yml](conf/config.yml)*, one list per host (inventory name); each rule has:

| Key | Value |
|---|---|
| *port* | port, e.g. '8443' (quoted) |
| *proto* | tcp, udp or any (default any) |
| *from* | source IP, preferably one of the IP variables (e.g. `"{{ admin_ip }}"`), or any (default any) |
| *comment* | the UFW rule comment, shown by `sudo ufw status` |

```yaml
ufw_rules:
  raspberry01:
    - { port: '22',   proto: tcp, from: "{{ admin_ip }}",   comment: SSH from admin laptop }
    - { port: '8443', proto: tcp, from: "{{ pi_core_ip }}", comment: Caddy -> Keycloak }
```

All rules are *allow* incoming rules. To add a rule, add it to the list of the host and run *[configure-windfire-infra.sh](configure-windfire-infra.sh)*; keep the 22/tcp rule from *admin_ip* identical to the one set by *[raspberry.yaml](raspberry.yaml)*.

The playbook only ensures the listed rules on a box where UFW is already active:

* it never enables, disables or resets UFW and never changes the default policies: those belong to *[raspberry.yaml](raspberry.yaml)*
* a listed rule that already exists with the same comment is left untouched; rules that are not listed stay as they are (unless pruning is enabled, see below)
* before changing any rule it checks that the play connects from *admin_ip* (anti-lockout check) and stops otherwise
* at the end it checks that UFW is still active and allows SSH from *admin_ip*

**Pruning.** With *ufw_prune_unlisted* set to true (default false, in *[config.yml](conf/config.yml)*) the playbook also deletes the rules of the box that are not in its *ufw_rules* list (including their (v6) twins). The 22/tcp rule from *admin_ip* is never deleted, and the prune is refused for a box with no rules listed. Enable it for one run only:

    ./configure-windfire-infra.sh -e ufw_prune_unlisted=true

**Dry run (--check).** Before changing anything, run the playbook in check mode to see what it would do:

    ./configure-windfire-infra.sh --check --diff
    ./configure-windfire-infra.sh --check --diff -e ufw_prune_unlisted=true

Nothing is changed on the boxes (the become password is still asked):

* the task *Ensure the UFW rules listed in ufw_rules* is reported *changed* for each rule that would be added; when the list matches the box, nothing is reported as changed
* with pruning enabled, the task *Show UFW rules that will be deleted* lists the rules that would be deleted, and the delete task is skipped
* the anti-lockout and final checks run as in a real run

Compare with `sudo ufw status numbered` on the box if something looks unexpected.

### Basic web infrastructure installation automation task
A very basic infrastructure to run web applications can be made of two major components:

* a Web Server where web application code is actually deployed and is run from - this can be implemented using **Apache2**
* a Proxy server that intercepts user requests and forward to the the Web Server, which actually serves the content back to the user - this can be implemented using **Nginx**

The **[raspberry-web.yaml](web/raspberry-web.yaml)** playbook is provided under *[web](web/)* sub-folder to deploy this basic web infrastructure by doing the following basic tasks on all Raspberry boxes consistently:

    * update package manager repo cache and upgrade installed packages on all Raspberry Pi boxes
    * install OpenSSL on all Raspberry Pi boxes
    * install Nginx on Raspberry Pi boxes marked as proxies and copy utility scripts for Nginx (provided in the *scripts* sub-folder)
    * install Apache2 on Raspberry Pi boxes marked as application servers and copy utility scripts for Apache2 (provided in the *scripts* sub-folder)

Some convenient scripts are provided under *[web](web/)* sub-folder::
* **[install-web.sh](web/install-web.sh)** uses *[raspberry-web.yaml](web/raspberry-web.yaml)* playbook to install Nginx and Apache2 on dedicated Raspberry Pi boxes consistently
* **[uninstall-web.sh](web/uninstall-web.sh)** uses *[raspberry-web-uninstall.yaml](web/raspberry-web-uninstall.yaml)* playbook to uninstall custom software from all Raspberry Pi boxes.

### Docker installation automation task
To automate Docker installation on Raspberry Pi boxes using Ansible: follow instructions at https://www.rs-online.com/designspark/raspberry-pi-4-personal-datacentre-part-1-ansible-docker-and-nextcloud.

General instructions on how to install and uninstall Docker on Raspberry Pi boxes are available at https://phoenixnap.com/kb/docker-on-raspberry-pi.

The **[raspberry-docker.yaml](docker/raspberry-docker.yaml)** playbook is provided under *[docker](docker/)* sub-folder to install Docker on all Raspberry Pi boxes.

Some convenient scripts are provided under *[docker](docker/)* sub-folder:
* **[install-docker-role.sh](docker/install-docker-role.sh)**, which installs *geerlingguy.docker_arm* role (see Ansible Galaxy https://galaxy.ansible.com/geerlingguy/docker_arm and GitHub Repo https://github.com/geerlingguy/ansible-role-docker_arm for more info) that installs Docker on Linux, specially tailored for ARM-based computers like the Raspberry Pi.
* **[install-docker.sh](docker/install-docker.sh)** uses *[raspberry-docker.yaml](docker/raspberry-docker.yaml)* playbook to activate a Docker role on all Raspberry boxes 
* **[uninstall-docker.sh](docker/uninstall-docker.sh)** uses *[raspberry-docker-uninstall.yaml](docker/raspberry-docker-uninstall.yaml)* playbook to uninstall Docker from all Raspberry Pi boxes.

## CI and dependency monitoring
The badge at the top of this page shows the status of the *[CI](.github/workflows/ci.yml)* workflow. The workflow runs on pull requests and on pushes to main, but its only job, dependency review, runs on pull requests: it fails if a pull request introduces a dependency with a vulnerability of high severity or above. Open the badge to see the individual runs and their logs.

GitHub Actions is the only dependency ecosystem in this repository. *[dependabot.yml](.github/dependabot.yml)* checks it weekly and opens pull requests for new versions of the actions, grouping minor and patch updates, with at most 5 open at a time.

Dependabot alerts are listed in the repository **Security** tab, under **Dependabot** (https://github.com/robipozzi/windfire-raspberry/security/dependabot). Each alert shows the affected package, its severity, the versions that fix it and, when available, a pull request with the fix. From the command line: `gh api repos/robipozzi/windfire-raspberry/dependabot/alerts`.

An empty alert list does not mean everything is safe:

* GitHub does not raise alerts for actions pinned to a commit SHA, which is how *[ci.yml](.github/workflows/ci.yml)* pins them, so review the weekly update pull requests instead
* Dependabot does not monitor what the playbooks install on the Raspberry Pi boxes (apt packages, the *geerlingguy.docker_arm* Ansible role)
<!-- windfire-maps retired (F20): pm2 was listed here, it was installed only for windfire-maps -->

## Projects
I use Raspberry in some projects I develop for fun.

### Home Automation
This is a side project that I am developing to handle sensors for various Home Automation tasks; see https://github.com/robipozzi/windfire-home-automation

## References
I wrote a more extensive article on how to use Ansible to automate various installation, configuration and application deployment tasks on Raspberry Pi, you can read it at the link here *https://bit.ly/3b13V9h*.