#!/bin/sh  

#################
#
# Setup (after One-Click-App configuration)  
# Run this setup script after successfully ran the Hetzner One-Click-App. 
#
#################

APP_PATH=${1:-'/opt/apps/jitsi-meet'}

# be aware that your vars are set and your .env is loaded ..
# remember: the env file is build from your cloud-config.yml  
# remember: set values for vars (for this script) in your env file  
. ${APP_PATH}/.env

# build domain string  
FQDN_AUTH=${FQDN_AUTH:-''}

# create simple list from frontend-folder
# NOTE: folder names will be set as adresses and expected to be in that form: subdomain.domain.tld  

# ORDERED list of template names
# NOTE: let var empty to use the folder names as given in your directory  
TEMPLATE_NAMES=${FQDN_TEMPLATES:-''}

cd ${APP_PATH}/custom-frontends
FOLDER_NAME_LIST=$(echo *)
cd - > /dev/null
count=1

fn_AddToList() {
    # expects $1 as the list
    # expects $2 as the new item
    if [ -n "${2}" ]
    then 
        LIST="${1} ${2}"
    else
        LIST="${1}"
    fi
    echo "${LIST}"
}

if [ -n "${TEMPLATE_NAMES}" ]
then
    for FOLDER_NAME in ${FOLDER_NAME_LIST}
    do
        TEMPLATE_NAME=$(echo ${TEMPLATE_NAMES} | awk -v count=${count} '{print $count}')
        if [ -n "${TEMPLATE_NAME}" ]
        then
            mv ${APP_PATH}/custom-frontends/${FOLDER_NAME} ${APP_PATH}/custom-frontends/${TEMPLATE_NAME}
            FQDN_LIST=$(fn_AddToList ${FQDN_LIST} ${TEMPLATE_NAME})
        else
            :          
        fi
        ((count++))
    done
else
    :
fi


for FQDN in ${FQDN_LIST}
do
    mkdir -p /var/www/${FQDN}
    mkdir -p ${APP_PATH}/configs/${FQDN}

    JITSI_WATERMARK_LINK=${FQDN}
    
    #################
    #
    # checkout your repository with your custom files. 
    # organizing downloaded files  
    #
    #################
    # after checkout specific files get picked, other files the repo are removed after setup 
    # expects the following repo structure:  
    # +-- ./
    # |   +-- apps
    # |   |   +-- jitsi-meet 
    # |   |   |   +-- configs
    # |   |   |   +-- custom-frontends
    # |   |   |   |   +-- subdomain.domain.tld (folder) 
    # |   |   |   |   |   +-- css
    # |   |   |   |   |   +-- images
    # |   |   |   |   |   +-- static
    # |   |   |   |   |   |   +-- privacy-policy-jitsi_de.html
    # |   |   |   |   |   |   +-- welcome.html
    # |   |   |   |   |   |   +-- close3.html
    # |   |   |   +-- helper
    # |   +-- web
    # |   |   +-- default
    # |   |   |   +-- css
    # |   |   |   |   +-- styles.css
    # |   |   |   +-- html  
    # |   |   |   |   +-- legal-notice
    # |   |   |   |   |   +-- legal-notice_de.html
    # |   +-- <other files/folders>

    # each subdomain gets its own copy from the base frontend
    # TODO: Create update routine which preserves your custom files..
    cp -R /usr/share/jitsi-meet/* /var/www/${FQDN}

    # create config for subdomain  
    sed "s~{{SUBDOMAIN.DOMAIN.TLD}}~${FQDN}~g" ${APP_PATH}/configs/templates/domain-config.js > /etc/jitsi/meet/${FQDN}-config.js

    # create interface for subdomain  
    sed -e "s~{{APP_NAME}}~${APP_NAME}~g" \
    -e "s~{{JITSI_WATERMARK_LINK}}~${JITSI_WATERMARK_LINK}~g" ${APP_PATH}/configs/templates/interface_config-template.js > ${APP_PATH}/configs/${FQDN}/interface_config.js
    # rm ${APP_PATH}/configs/interface_config-template.js

    # symlink the interface config (overwrites existing file) from subdomain to custom frontend
    # NOTE: the copy of frontend files should be easily overridden if you update the app  
    ln -sf ${APP_PATH}/configs/${FQDN}/interface_config.js /var/www/${FQDN}/interface_config.js

    # language files
    ln -sf ${APP_PATH}/configs/templates/main-de.json /var/www/${FQDN}/lang/main-de.json
    ln -sf ${APP_PATH}/configs/templates/main.json /var/www/${FQDN}/lang/main.json

    #################
    # 
    # setup your custom jitsi frontend 
    #
    #################

    # NOTICE: no blanks in file name allowed!
    # iterator separates at blanks
    STATIC_FILES="close3.html" 

    for FILE in ${STATIC_FILES}
    do
        # replace domain-placeholder in current file  
        # NOTE: breaks in ZSH-shell!
        CONTENT_REPLACEMENT=$(sed -e "s~{{FQDN}}~${FQDN}~g" ${APP_PATH}/custom-frontends/${FQDN}/templates/static/${FILE})
        # temp file 
        # note: echo with double quotes to keep the line breaks..
        mkdir -p ${APP_PATH}/custom-frontends/${FQDN}/static
        echo "${CONTENT_REPLACEMENT}" > ${APP_PATH}/custom-frontends/${FQDN}/static/${FILE}
        # symlink file 
        ln -sf ${APP_PATH}/custom-frontends/${FQDN}/static/${FILE} /var/www/${FQDN}/static/${FILE}
    done

    # replace placeholder in welcome page with your custom page
    # troubleshooting sed @see: https://www.gnu.org/software/sed/manual/html_node/Multiple-commands-syntax.html 
    sed -e "s~{{FQDN}}~${FQDN}~g" \
    -e "s~{{NAME_LEGAL_NOTICE}}~${NAME_LEGAL_NOTICE}~g" \
    -e "s~{{NAME_PRIVACY_POLICY}}~${NAME_PRIVACY_POLICY}~g" \
    -e "s~{{FILENAME_LEGAL_NOTICE}}~${FILENAME_LEGAL_NOTICE}~g" \
    -e "s~{{FILENAME_PRIVACY_POLICY}}~${FILENAME_PRIVACY_POLICY}~g" ${APP_PATH}/custom-frontends/${FQDN}/templates/static/welcome.html > ${APP_PATH}/custom-frontends/${FQDN}/static/welcomePageAdditionalContent.html

    ln -sf ${APP_PATH}/custom-frontends/${FQDN}/static/welcomePageAdditionalContent.html /var/www/${FQDN}/static/welcomePageAdditionalContent.html

    # symlink image files  
    IMAGE_FILES="watermark.svg header.jpg header.png waving-hand.svg"

    for FILE in ${IMAGE_FILES}
    do
        # symlink to ../jitsi-meet/images (no changes to filenames)
        ln -sf ${APP_PATH}/custom-frontends/${FQDN}/templates/images/${FILE} /var/www/${FQDN}/images/${FILE}
    done

    # symlink single files to ../jitsi-meet
    ln -sf ${APP_PATH}/custom-frontends/${FQDN}/templates/css/all.css /var/www/${FQDN}/css/all.css
    ln -sf ${APP_PATH}/custom-frontends/${FQDN}/templates/static/css /var/www/${FQDN}/static/css
    ln -sf ${APP_PATH}/custom-frontends/${FQDN}/templates/images/favicon.ico /var/www/${FQDN}/favicon.ico

    # renaming and parsing template html files to destination folder  
    sed -e "s~{{FILENAME_LEGAL_NOTICE}}~${FILENAME_LEGAL_NOTICE}~g" \
    -e "s~{{NAME_LEGAL_NOTICE}}~${NAME_LEGAL_NOTICE}~g" \
    -e "s~{{NAME_PRIVACY_POLICY}}~${NAME_PRIVACY_POLICY}~g" \
    -e "s~{{FILENAME_PRIVACY_POLICY}}~${FILENAME_PRIVACY_POLICY}~g" ${APP_PATH}/custom-frontends/${FQDN}/templates/static/legal-notice_de.html.template > ${APP_PATH}/custom-frontends/${FQDN}/static/${FILENAME_LEGAL_NOTICE}
    ln -sf ${APP_PATH}/custom-frontends/${FQDN}/static/${FILENAME_LEGAL_NOTICE} /var/www/${FQDN}/static/${FILENAME_LEGAL_NOTICE}

    sed -e "s~{{FILENAME_PRIVACY_POLICY}}~${FILENAME_PRIVACY_POLICY}~g" \
    -e "s~{{NAME_PRIVACY_POLICY}}~${NAME_PRIVACY_POLICY}~g" ${APP_PATH}/custom-frontends/${FQDN}/templates/static/privacy-policy-jitsi_de.html.template > ${APP_PATH}/custom-frontends/${FQDN}/static/${FILENAME_PRIVACY_POLICY}
    ln -sf ${APP_PATH}/custom-frontends/${FQDN}/static/${FILENAME_PRIVACY_POLICY} /var/www/${FQDN}/static/${FILENAME_PRIVACY_POLICY}

done


#################
# 
# modifying and organizing config files
#
#################

# modifying cfg.lua
# extract the password 
# pattern:
# - zero or more blanks at beginning of line
# - followed by 'external_service_secret :"' (note the double quote)
# - followed by undefined number of any char, ends with '";' (double quote and semicolon)  
# - the pattern between the double quotes is catched as group and substituted to stdout 
# - stdout = passwordstring is stored into $EXTERNAL_SERVICE_SECRET  
# expected pattern in <domain>.cfg.lua (NOTE the blanks!): external_service_secret = "<chars>"; 
EXTERNAL_SERVICE_SECRET=$(sed -n 's/ \{0,\}external_service_secret = \"\(.*\)\"\;$/\1/p' /etc/prosody/conf.avail/${FQDN_AUTH}.cfg.lua)

# parse config files to destination  
sed -e "s~{{SUBDOMAIN.DOMAIN.TLD}}~${FQDN_AUTH}~g" \
-e "s~{{EXTERNAL_SERVICE_SECRET}}~${EXTERNAL_SERVICE_SECRET}~g" ${APP_PATH}/configs/templates/domain.cfg.lua > /etc/prosody/conf.avail/${FQDN_AUTH}.cfg.lua


# modifying jicofo.conf
# extract the password
# pattern:
# - zero or more blanks at beginning of line
# - followed by 'password :"' (note the double quote)
# - followed by undefined number of any char, ends with '"' (double quote)  
# - the pattern between the double quotes is catched as group and substituted to stdout 
# - stdout = passwordstring is stored into $JICOFO_PASSWORD  
# expected pattern in jicofo.conf: password: "<chars>" 
JICOFO_PASSWORD=$(sed -n 's/ \{0,\}password: \"\(.*\)\"$/\1/p' /etc/jitsi/jicofo/jicofo.conf)

sed -e "s~{{JICOFO_PASSWORD}}~${JICOFO_PASSWORD}~g" \
-e "s~{{SUBDOMAIN.DOMAIN.TLD}}~${FQDN_AUTH}~g" ${APP_PATH}/configs/templates/jicofo-template.conf > /etc/jitsi/jicofo/jicofo.conf



# adds new user (XMPP)
# NOTE: register has no flags (instead ejabberd..) @see man prosodyctl  
prosodyctl register ${PROSODY_USER} ${FQDN_AUTH} ${PROSODY_PASS}
systemctl restart prosody

# restarts with new configs  
systemctl restart jicofo
systemctl restart jitsi-videobridge2


#################
# 
# ssh hardening
#################

# change settings in /etc/ssh/sshd_config  
# @see: https://community.hetzner.com/tutorials/basic-cloud-config/de  
sed -i -e "/^\(#\|\)PermitRootLogin/s/^.*$/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "/^\(#\|\)PasswordAuthentication/s/^.*$/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i -e "/^\(#\|\)X11Forwarding/s/^.*$/X11Forwarding no/" /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)KbdInteractiveAuthentication/s/^.*$/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sed -i -e '/^\(#\|\)ChallengeResponseAuthentication/s/^.*$/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i -e "/^\(#\|\)MaxAuthTries/s/^.*$/MaxAuthTries ${SSH_MAX_AUTHTRIES}/" /etc/ssh/sshd_config
sed -i -e "/^\(#\|\)AllowTcpForwarding/s/^.*$/AllowTcpForwarding no/" /etc/ssh/sshd_config
sed -i -e "/^\(#\|\)AllowAgentForwarding/s/^.*$/AllowAgentForwarding no/" /etc/ssh/sshd_config
sed -i -e "/^\(#\|\)Port/s/^.*$/Port ${SSH_PORT}/" /etc/ssh/sshd_config
sed -i -e "/^\(#\|\)AuthorizedKeysFile/s/^.*$/AuthorizedKeysFile .ssh\/authorized_keys/" /etc/ssh/sshd_config

# set allowed users  
# more than one user: user name separated by blanks  
sed -i "\$a AllowUsers ${SSH_USERS}" /etc/ssh/sshd_config

# override firewall settings from cloud-init.yaml  
# close the default ssh port
if [ ${SSH_PORT} -ne 22 ]
then 
    ufw deny 22/tcp 
else 
    :
fi

systemctl restart ufw
systemctl restart ssh
systemctl restart nginx

# housekeeping
# rm -R /opt/apps/jitsi-meet/custom-frontends