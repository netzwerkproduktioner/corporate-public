#!/bin/sh  

# TODO: build an updater..
# - fresh pull from repo
# - update template files
# - update config files  

# APP_PATH=${1:-'/opt/apps/jitsi-meet'}

# # Updating
# # check if there is already an 'customizations'-folder  
# if [ -d ${APP_PATH} ]
# then
#     # removing previous installation 
#     echo "removing existing files .."
#     rm -Rf ${APP_PATH}
#     mkdir -p ${APP_PATH}
#     rm -Rf /var/www/jitsi-meet/${FQDN}
#     # remove /var/www/..
# else
#     echo "creating folder with subfolder .."
#     mkdir -p ${APP_PATH}
# fi