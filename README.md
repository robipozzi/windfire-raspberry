# Raspberry Pi automation
This repository holds scripts, playbooks and configurations to automate infrastructure configuration tasks on Raspberry Pi boards.

## Ansible configuration setup
The scripts provided are based on Ansible technology (https://www.ansible.com/) for task automation; refer to Ansible technical 
documentation (https://docs.ansible.com/) for detailed instructions regarding installation and setup.

Ansible uses ssh to connect to the managed infrastructure, so you will first need to generate an ssh key pair; the script *ansible-initialize.sh*, provided in the root folder of this repo, copies the public ssh key to a remote destination (you will need to pass it as a parameter when you launch the script), assuming you generated a key called *ansible_rsa* and saved it in *.ssh* sub-folder under your user home directory.

A file, named *ansible.cfg*, is also provided to set basic configurations needed to run Ansible; if you launch Ansible from the repo root directory, this file will be read and used as the source for configuration settings (unless you have set an ANSIBLE_CONFIG environment variable, which has precedence), the basic configuration you should have is something like this:

![](images/ansible-config.png)
where:

* *private_key_file* points to the SSH private key you have previously generated, used by Ansible to connect and launch tasks on the target Raspberry Pi;
* *inventory* defines where Ansible will look for the inventory file, which is used by Ansible to know which servers to connect and manage.

Change the parameters according to your environment.

## Apache2 installation automation task
A couple of convenient scripts are provided:
* #install.sh#: it uses *raspberry.yaml* playbook that does the following tasks: 

    * installs Apache2 to Raspberry Pi;
    * copies some utility scripts (provided in the *scripts* sub-folder) to Raspberry Pi.
* *uninstall.sh*: it uses *raspberry-uninstall.yaml* playbook to uninstall Apache2 from Raspberry Pi.

Both playbooks refer to yaml files provided in *conf* sub-folder for common variables setup and usage.

## References
I wrote a more extensive article on how to use Ansible to automate various installation, configuration and application deployment tasks on Raspberry Pi, you can read it at the link here *https://bit.ly/3b13V9h*.