source ../../setenv.sh

###### Variable section - START
SCRIPT=pip-install.sh
###### Variable section - END

# ***** Function section - START
main()
{
    sudo pip3 install -r requirements.txt
}
# ***** Function section - END

# ##############################################
# #################### MAIN ####################
# ##############################################
main