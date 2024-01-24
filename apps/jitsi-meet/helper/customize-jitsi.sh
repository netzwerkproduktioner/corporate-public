#!/bin/sh  

#################
#
# Setup (after One-Click-App configuration)  
# Run this setup script after successfully ran the Hetzner One-Click-App. 
#
#################

# be aware that your vars are set and your .env is loaded ..
# remember: the env file is build from your cloud-config.yml  
# remember: set values for vars (for this script) in your env file  
. /opt/.env

# build domain string  
FQDN=${JITSI_FQDN=${JITSI_SUBDOMAIN}.${JITSI_DOMAIN}.${JITSI_TLD}}

# Updating
# check if there is already an 'customizations'-folder  
if [ -d ${CUSTOMIZATIONS_PATH} ]
then
    # removing previous installation 
    echo "removing existing files .."
    rm -Rf ${CUSTOMIZATIONS_PATH}
    mkdir -p ${CUSTOMIZATIONS_PATH}
    rm -Rf /var/www/jitsi-meet/${FQDN}
    # remove /var/www/..
else
    echo "creating folder with subfolder .."
    mkdir -p ${CUSTOMIZATIONS_PATH}
fi

# checkout your repository with your custom files. 
# after checkout specific files get picked, other files the repo are removed after setup 
# CUSTOMIZATIONS_PATH=/opt/apps/jitsi-meet/
git clone ${CUSTOMIZATIONS_REPO} /opt/apps/_temp/repo
mv -f /opt/apps/_temp/repo/apps/jitsi-meet/* ${CUSTOMIZATIONS_PATH}/

# renames default folder to local customization 
mv -f ${CUSTOMIZATIONS_PATH}/custom-frontend/subdomain.domain.tld/ ${CUSTOMIZATIONS_PATH}/custom-frontend/${FQDN}/

# modifying cfg.lua
# extract the password 
# pattern:
# - zero or more blanks at beginning of line
# - followed by 'external_service_secret :"' (note the double quote)
# - followed by undefined number of any char, ends with '";' (double quote and semicolon)  
# - the pattern between the double quotes is catched as group and substituted to stdout 
# - stdout = passwordstring is stored into $EXTERNAL_SERVICE_SECRET  
# expected pattern in <domain>.cfg.lua (NOTE the blanks!): external_service_secret = "<chars>"; 
EXTERNAL_SERVICE_SECRET=$(sed -n 's/ \{0,\}external_service_secret = \"\(.*\)\"\;$/\1/p' /etc/prosody/conf.avail/${FQDN}.cfg.lua)

# parse config files to destination  
sed -e "s/{{SUBDOMAIN.DOMAIN.TLD}}/${FQDN}/g" \
-e "s/{{EXTERNAL_SERVICE_SECRET}}/${EXTERNAL_SERVICE_SECRET}/g" ${CUSTOMIZATIONS_PATH}/configs/domain.cfg.lua > /etc/prosody/conf.avail/${FQDN}.cfg.lua

sed "s/{{SUBDOMAIN.DOMAIN.TLD}}/${FQDN}/g" ${CUSTOMIZATIONS_PATH}/configs/domain-config.js > /etc/jitsi/meet/${FQDN}-config.js

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


sed -e "s/{{JICOFO_PASSWORD}}/${JICOFO_PASSWORD}/g" \
-e "s/{{SUBDOMAIN.DOMAIN.TLD}}/${FQDN}/g" ${CUSTOMIZATIONS_PATH}/configs/jicofo-template.conf > /etc/jitsi/jicofo/jicofo.conf

mv -f ${CUSTOMIZATIONS_PATH}/configs/interface_config-template.js ${CUSTOMIZATIONS_PATH}/configs/interface_config.js
ln -sf ${CUSTOMIZATIONS_PATH}/configs/interface_config.js /usr/share/jitsi-meet/interface_config.js
ln -sf ${CUSTOMIZATIONS_PATH}/configs/main-de.json /usr/share/jitsi-meet/lang/main-de.json
ln -sf ${CUSTOMIZATIONS_PATH}/configs/main.json /usr/share/jitsi-meet/lang/main.json

# reloads modified config file
systemctl restart prosody
systemctl restart jicofo
systemctl restart jitsi-videobridge2

# adds new user
# NOTE: register has no flags (instead ejabberd..) @see man prosodyctl  
prosodyctl register ${PROSODY_USER} ${FQDN} ${PROSODY_PASSWORD}
systemctl restart prosody

# restarts with new configs  
systemctl restart jicofo
systemctl restart jitsi-videobridge2


# setup your custom frontend 
# parse static files before moving them  

# NOTICE: no blanks in file name allowed!
# iterator separates at blanks
STATIC_FILES="close3.html close2.html" 

for FILE in ${STATIC_FILES}
do
    # replace domain-placeholder in current file  
    CONTENT_REPLACEMENT=$(sed -e "s/{{FQDN}}/${FQDN}/g" ${CUSTOMIZATIONS_PATH}/static/${FILE})
    # temp file 
    # note: echo with double quotes to keep the line breaks..
    echo "${CONTENT_REPLACEMENT}" > ${FILE}
done

# move files
mkdir -p /var/www/jitsi-meet/${FQDN}
mv -f ${CUSTOMIZATIONS_PATH}/custom-frontend/${FQDN}/* /var/www/jitsi-meet/${FQDN}/

# symlink files from directory outside the default installation into the installation paths 
ln -sf /var/www/jitsi-meet/${FQDN}/images/watermark.svg /usr/share/jitsi-meet/images/watermark.svg
ln -sf /var/www/jitsi-meet/${FQDN}/images/favicon.ico /usr/share/jitsi-meet/images/favicon.ico
ln -sf /var/www/jitsi-meet/${FQDN}/css/all.css /usr/share/jitsi-meet/css/all.css
ln -sf /var/www/jitsi-meet/${FQDN}/static/css /usr/share/jitsi-meet/static/css
ln -sf /var/www/jitsi-meet/${FQDN}/static/images /usr/share/jitsi-meet/static/images

ln -sf /var/www/jitsi-meet/${FQDN}/images/header.jpg /usr/share/jitsi-meet/images/header.jpg
ln -sf /var/www/jitsi-meet/${FQDN}/images/header.png /usr/share/jitsi-meet/images/header.png

# rename files from default to your local environment (your vars in your env)
# your legal notice comes from a different folder 
mv -f /opt/apps/_temp/repo/web/default/css/styles.css /var/www/jitsi-meet/${FQDN}/static/css/styles.css

# TODO: remove mkdir - folder already exists in repo, otherwise symlinking (see above) would fail  
mkdir -p /var/www/jitsi-meet/${FQDN}/static/images
mv -f /opt/apps/_temp/repo/web/default/images/favicon.ico /var/www/jitsi-meet/${FQDN}/static/images/favicon.ico
# renaming and parsing
sed -e "s/{{FILENAME_LEGAL_NOTICE}}/${FILENAME_LEGAL_NOTICE}/g" \
-e "s/{{FILENAME_PRIVACY_POLICY}}/${FILENAME_PRIVACY_POLICY}/g" /opt/apps/_temp/repo/web/default/html/legal-notice/legal-notice_de.html > /var/www/jitsi-meet/${FQDN}/static/${FILENAME_LEGAL_NOTICE}

mv -f /var/www/jitsi-meet/${FQDN}/static/privacy-policy-jitsi_de.html /var/www/jitsi-meet/${FQDN}/static/${FILENAME_PRIVACY_POLICY}

ln -sf /var/www/jitsi-meet/${FQDN}/static/${FILENAME_LEGAL_NOTICE} /usr/share/jitsi-meet/static/${FILENAME_LEGAL_NOTICE}
ln -sf /var/www/jitsi-meet/${FQDN}/static/${FILENAME_PRIVACY_POLICY} /usr/share/jitsi-meet/static/${FILENAME_PRIVACY_POLICY}

# replace default welcome page with your custom page
# troubleshooting sed @see: https://www.gnu.org/software/sed/manual/html_node/Multiple-commands-syntax.html 
sed -e "s/{{FQDN}}/${FQDN}/g" \
-e "s/{{NAME_LEGAL_NOTICE}}/${NAME_LEGAL_NOTICE}/g" \
-e "s/{{NAME_PRIVACY_POLICY}}/${NAME_PRIVACY_POLICY}/g" \
-e "s/{{FILENAME_LEGAL_NOTICE}}/${FILENAME_LEGAL_NOTICE}/g" \
-e "s/{{FILENAME_PRIVACY_POLICY}}/${FILENAME_PRIVACY_POLICY}/g" /var/www/jitsi-meet/${FQDN}/static/welcome.html > /var/www/jitsi-meet/${FQDN}/static/welcomePageAdditionalContent.html
rm /var/www/jitsi-meet/${FQDN}/static/welcome.html

ln -sf /var/www/jitsi-meet/${FQDN}/static/welcomePageAdditionalContent.html /usr/share/jitsi-meet/static/welcomePageAdditionalContent.html

# housekeeping
rm -R /opt/apps/_temp
rm -R /opt/apps/jitsi-meet/custom-frontend
rm -R /opt/apps/jitsi-meet/helper
# rm -R /opt/.env
# rm /opt/customize-jitsi.sh