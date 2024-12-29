#!/bin/sh  

#################
#
# Setup (after One-Click-App configuration)  
# Run this setup script after successfully ran the Hetzner One-Click-App. 
#
#################

#################
#
# Updating..
#
#################
# currently there are problems with default installation from Hetzner
# you have to run update and upgrade after successfully ran the one-click-installer  
# jitsi-meet-prosody: Installed: 1.0.8302-1
# jitsi-meet: Installed: 2.0.9909-1
apt-get update && apt-get -yyq upgrade

systemctl restart prosody
systemctl restart jicofo
systemctl restart jitsi-videobridge2

#################
# some vars used in this script
count=1
CERTBOT_DOMAINS=

#################
APP_PATH=${1:-'/opt/apps/jitsi-meet'}

mkdir ${APP_PATH}/backup

# be aware that your vars are set and your .env is loaded ..
# remember: the env file is build from your cloud-config.yml  
# remember: set values for vars (for this script) in your env file  
. ${APP_PATH}/.env

# create simple list from frontend-folder
# NOTE: folder names will be set as adresses and expected to be in that form: subdomain.domain.tld  

# ORDERED list of template names
# NOTE: let var empty to use the folder names as given in your directory  
TEMPLATE_NAMES="${FQDN_TEMPLATES}"


fn_getTemplateFolderList() {
    cd ${APP_PATH}/custom-frontends
    FOLDER_NAME_LIST=$(echo *)
    cd - > /dev/null

    echo ${FOLDER_NAME_LIST}
}

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
    FOLDER_NAME_LIST=$(fn_getTemplateFolderList ${APP_PATH})
    for TEMPLATE_NAME in ${TEMPLATE_NAMES}
    do
        FOLDER_NAME=$(echo ${FOLDER_NAME_LIST} | awk -v count=${count} '{print $count}')
        if [ -n "${FOLDER_NAME}" ]
        then
            if [ "${TEMPLATE_NAME}" != "${FOLDER_NAME}" ]
            then
                # rename folder
                mv ${APP_PATH}/custom-frontends/${FOLDER_NAME} ${APP_PATH}/custom-frontends/${TEMPLATE_NAME}
            else
                # skip renaming, folders have identical names  
                :
            fi
            FQDN_LIST=$(fn_AddToList ${FQDN_LIST} ${TEMPLATE_NAME})
        else
            # no more entries in your FOLDER_NAME_LIST
            # this template (and following) will not on the list for setting up sites
            # TODO: add folder from copy of base folder (/usr/share/jitsi-meet) 
            # TODO: cp with new name ${TEMPLATE_NAME} at destination  
            echo "no folder for template ${TEMPLATE_NAME} .. skipping .."
            break
        fi
        count=$( expr ${count} + 1 )
    done
else
    # no template names given, so use name of template folders as domains.. 
    FQDN_LIST=$(fn_getTemplateFolderList ${APP_PATH})
fi

#################
# 
# modifying and organizing config files
#
#################

fn_MofifyCfgLua() {
    # expects #1 parameter ${APP_PATH}
    APP_PATH=${1}
    # expects #2 parameter ${FQDN}
    FQDN=${2}

    FQDN_AUTH=${3}

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

    # backup the initial file  
    cp /etc/prosody/conf.avail/${FQDN_AUTH}.cfg.lua ${APP_PATH}/backup/${FQDN_AUTH}.cfg.lua.backup

    # parse config files to destination  
    sed -e "s~{{SUBDOMAIN.DOMAIN.TLD}}~${FQDN}~g" \
    -e "s~{{EXTERNAL_SERVICE_SECRET}}~${EXTERNAL_SERVICE_SECRET}~g" ${APP_PATH}/configs/templates/domain.cfg.lua > /etc/prosody/conf.avail/${FQDN}.cfg.lua

}

# modify prosody cfg.lua for the main user (FQDN_AUTH)  
fn_MofifyCfgLua ${APP_PATH} ${FQDN_AUTH} ${FQDN_AUTH}

fn_ModifyJicofoConf() {
    # expects #1 ${APP_PATH}
    APP_PATH=${1}    
    # expects #2 ${FQDN}
    FQDN=${2}

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

    # backup the initial file  
    cp /etc/jitsi/jicofo/jicofo.conf ${APP_PATH}/backup/jicofo.conf.backup

    sed -e "s~{{JICOFO_PASSWORD}}~${JICOFO_PASSWORD}~g" \
    -e "s~{{SUBDOMAIN.DOMAIN.TLD}}~${FQDN}~g" ${APP_PATH}/configs/templates/jicofo-template.conf > /etc/jitsi/jicofo/jicofo.conf
}

# modify jicofo.conf for the main user (FQDN_AUTH)  
fn_ModifyJicofoConf ${APP_PATH} ${FQDN_AUTH}

# replace -config.js for FQDN_AUTH from template  
# TODO: refactor with substition on the original file (update resistent)  
sed "s~{{SUBDOMAIN.DOMAIN.TLD}}~${FQDN_AUTH}~g" ${APP_PATH}/configs/templates/domain-config.js > /etc/jitsi/meet/${FQDN_AUTH}-config.js

#################
# 
# running configuration for your domains (with certificates)  
#
#################

# stop nginx before running installations
systemctl stop nginx

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

    # TODO: remove after debugging  
    # create config for subdomain  
    # sed "s~{{SUBDOMAIN.DOMAIN.TLD}}~${FQDN}~g" ${APP_PATH}/configs/templates/domain-config.js > /etc/jitsi/meet/${FQDN}-config.js

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

    # lets replace some things..
    # awk
    # the regexp '/server {/' grabs everthing starting with 'server {' until the next occurrence of '}' at the beginning auf line (with no intention) 
    # the result is piped directly to sed  
    # sed
    # ^\([ ]*\)root - gets every blank from beginning of line followed by 'root', stored as group
    # \(.*$\) - stores everyting after 'root' until end of line, into a group
    # \1 first group (blanks..) are added before the replacement string 'root /var/..'  
    # the result is written to new file in sites-available
    # NOTE: you have to replace FQDN_AUTH before adding/modifing the path to the main (FQDN_AUTH) config
    awk '/server {/ {flag=1} flag; /^}/ {flag=0}' /etc/nginx/sites-available/${FQDN_AUTH}.conf | \
    sed -e "s~^\([ ]*\)root\(.*$\)~\1root \/var\/www/${FQDN};~g" \
    -e "s~${FQDN_AUTH}~${FQDN}~g" \
    -e "s~set\ \$config_js_location.*$~set \$config_js_location \/etc\/jitsi\/meet\/${FQDN_AUTH}-config.js;~g" > /etc/nginx/sites-available/${FQDN}.conf

    # enable sites 
    ln -sf /etc/nginx/sites-available/${FQDN}.conf /etc/nginx/sites-enabled/${FQDN}.conf

    # from the docs  
    # certonly    Obtain or renew a certificate, but do not install it
    # -d DOMAINS  Comma-separated list of domains to obtain a certificate for
    # certbot certonly --nginx -d <comma separated domains>
    # remove trailing comma
    # certonly --standalone copies certs to /etc/letsencrypt/live/<FQDN>
    # NOTE: to remove 'old' certificates you have to run: 
    # certbot delete -n --cert-name <your-cert-name>
    certbot certonly --standalone -d ${FQDN}

done

# restart nginx after all operations above  
systemctl start nginx

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

# TODO: why is ssh.service disabled after running the initialization?
systemctl enable ssh.service

systemctl restart ufw
systemctl restart ssh
systemctl restart nginx

# housekeeping
# rm -R /opt/apps/jitsi-meet/custom-frontends
# rm /etc/nginx/sites-enabled/default