source ../../setenv.sh

###### Variable section - START
SCRIPT=pip-install.sh
###### Variable section - END

# ***** Function section - START
main()
{
    sudo pip install -r requirements.txt
}
# ***** Function section - END

# ##############################################
# #################### MAIN ####################
# ##############################################
main