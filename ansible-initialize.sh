source setenv.sh

###### Variable section - START
DESTINATION=$1
SCRIPT="ansible-initialize.sh"
###### Variable section - END

#######################################################
## It copies Ansible SSH public key to a destination ##
#######################################################
sshCopy()
{
	echo ${cyn}Copying Ansible SSH key to destination ...${end}
    ssh-copy-id -i $HOME/.ssh/ansible_rsa pi@$DESTINATION
    echo ${cyn}Done${end}
}

###############
## printHelp ##
###############
printHelp()
{
	printf "${red}Missing IP or Hostname destination to copy SSH key${end}\n"
  	printf "${cyn}Usage: ./$SCRIPT <DESTINATION>${end}\n"
    printf "\n"
    printf "${cyn}Example: ./$SCRIPT 192.168.4.290${end}\n"
	exit
}

###### Main section
if [ -z $DESTINATION ]; then 
	printHelp
else
	RUN_FUNCTION=sshCopy
	$RUN_FUNCTION
fi