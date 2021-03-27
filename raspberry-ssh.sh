source setenv.sh

###### Variable section - START
OPTION=$1
DESTINATION=
SCRIPT="raspberry-ssh.sh"
###### Variable section - END

############
## sshRun ##
############
sshRun()
{
	if [ -z $PLATFORM_OPTION ]; then 
        printSelectDestination
    fi
	ssh pi@$DESTINATION -i /Users/robertopozzi/.ssh/ansible_rsa
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

printSelectDestination()
{
	echo ${grn}Select Raspberry Box platform to connect: ${end}
	echo "${grn}1. raspberry1${end}"
    echo "${grn}2. raspberry2${end}"
	read OPTION
	setDestination
}

setDestination()
{
	case $OPTION in
		1)  DESTINATION="raspberry1"
			;;
        2)  DESTINATION="raspberry2"
			;;
		*) 	printf "\n${red}No valid option selected${end}\n"
			printSelectDestination
			;;
	esac
}

# ##############################################
# #################### MAIN ####################
# ##############################################
# ************ START evaluate args ************"
if [ "$1" != "" ]; then
    setDestination
fi
# ************** END evaluate args **************"
RUN_FUNCTION=sshRun
$RUN_FUNCTION