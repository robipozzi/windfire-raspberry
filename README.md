# Raspberry Pi automation
This repository holds scripts, playbooks and configurations to automate infrastructure configuration tasks on Raspberry Pi boards.

## Ansible configuration setup
The scripts provided are based on Ansible technology (https://www.ansible.com/) for task automation; refer to Ansible technical 
documentation (https://docs.ansible.com/) for detailed instructions regarding installation and setup.

Ansible uses ssh to connect to the managed infrastructure, so you will first need to generate an ssh key pair; the script *ansible-initialize.sh*, provided in the root folder of this repo, copies the public ssh key to a remote destination (you will need to pass it as a parameter when you launch the script), assuming you generated a key called *ansible_rsa* and saved it in *.ssh* sub-folder under your user home directory.

A file, named *ansible.cfg*, is also provided to set basic configurations needed to run Ansible; if you launch Ansible from the repo root directory, this file will be read and used as the source for configuration settings (unless you have set an ANSIBLE_CONFIG environment variable, which has precedence), the basic configuration you should have is something like this:

![](images/ansible-config.png)

where:

* *private_key_file* points to the SSH private key you have previously generated, used by Ansible to connect and launch tasks on the target Raspberry Pi box, change it according to your environment;
* *inventory* defines where Ansible will look for the inventory file, which is used by Ansible to know which servers to connect and manage.

## Ansible configuration setup

## References
I  *https://bit.ly/3b13V9h*