#!/bin/bash  

#################
# Setup (after One-Click-App configuration)  
# Run this setup script after successfully ran the Hetzner One-Click-App. 
# Notice: 
#################

# be aware that your vars are set and your .env is loaded ..

# Updating
# check if there is already an 'customizations'-folder  
if [ -d ${CUSTOMIZATIONS_PATH} ]
then
    # removing previous installation 
    rm -Rf ${CUSTOMIZATIONS_PATH}
else
    mkdir -p ${CUSTOMIZATIONS_PATH}
fi

# checkout your repository with your custom files. 
# after checkout specific files get picked, other files the repo are removed immediately
# CUSTOMIZATIONS_PATH=/opt/apps/jitsi-meet/
git clone https://github.com/netzwerkproduktioner/corporate-public.git /opt/repo
mv /opt/repo/apps/jitsi-meet ${CUSTOMIZATIONS_PATH}
# housekeeping
rm -R /opt/repo

# build domain string  
FQDN=${JITSI_FQDN=${JITSI_SUBDOMAIN}.${JITSI_DOMAIN}.${JITSI_TLD}}

# parse config files to destination  
sed -e "s/{{SUBDOMAIN.DOMAIN.TLD}}/${FQDN}/g" \
-e "s/{{EXTERNAL_SERVICE_SECRET}}/${EXTERNAL_SERVICE_SECRET}/g" ${CUSTOMIZATIONS_PATH}/configs/domain.cfg.lua > /etc/prosody/conf.avail/${FQDN}.cfg.lua

sed "s/{{SUBDOMAIN.DOMAIN.TLD}}/${FQDN}/g" ${CUSTOMIZATIONS_PATH}/configs/domain-config.js > /etc/jitsi/meet/${FQDN}-config.js

sed -e "s/{{YOUR_JICOFO_PASSWORD}}/${JICOFO_PASSWORD}/g" \
-e "s/{{SUBDOMAIN.DOMAIN.TLD}}/${FQDN}/g" ${CUSTOMIZATIONS_PATH}/configs/jicofo-template.conf > /etc/jitsi/jicofo/jicofo.conf

mv -f ${CUSTOMIZATIONS_PATH}/configs/interface_config-template.js ${CUSTOMIZATIONS_PATH}/configs/interface_config.js
ln -sf ${CUSTOMIZATIONS_PATH}/configs/interface_config.js /usr/share/jitsi-meet/interface_config.js


# create prosody users
prosodyctl register ${PROSODY_USER} ${FQDN} ${PROSODY_PASSWORD}
systemctl restart prosody

# restarts with new configs  
systemctl restart jicofo
systemctl restart jitsi-videobridge2


# setup your custom frontend 
mkdir -p /var/www/jitsi-meet/${FQDN}
mv -f ${CUSTOMIZATIONS_PATH}/custom-frontend/${FQDN}/* /var/www/jitsi-meet/${FQDN}/

# symlink files from directory outside the default installation into the installation paths 
ln -sf /usr/share/jitsi-meet/images/watermark.svg /var/www/jitsi-meet/${FQDN}/images/watermark.svg
ln -sf /usr/share/jitsi-meet/images/favicon.ico /var/www/jitsi-meet/${FQDN}/images/favicon.ico 
ln -sf /usr/share/jitsi-meet/css/all.css /var/www/jitsi-meet/${FQDN}/css/all.css
ln -sf /usr/share/jitsi-meet/static/css/ /var/www/jitsi-meet/${FQDN}/static/css/

ln -sf /var/www/jitsi-meet/images/${FQDN}/header.jpg /usr/share/jitsi-meet/images/header.jpg

# rename files from default to your local environment (your vars in your env)
mv -f /var/www/jitsi-meet/${FQDN}/static/legal-notice_de.html /var/www/jitsi-meet/${FQDN}/static/${FILENAME_LEGAL_NOTICE}
mv -f /var/www/jitsi-meet/${FQDN}/static/privacy-policy-jitsi_de.html /var/www/jitsi-meet/${FQDN}/static/${FILENAME_PRIVACY_POLICY}

ln -sf /var/www/jitsi-meet/${FQDN}/static/${FILENAME_LEGAL_NOTICE} /usr/share/jitsi-meet/static/${FILENAME_LEGAL_NOTICE}
ln -sf /var/www/jitsi-meet/${FQDN}/static/${FILENAME_PRIVACY_POLICY} /usr/share/jitsi-meet/static/${FILENAME_PRIVACY_POLICY}

# replace default welcome page with your custom page
# troubleshooting sed @see: https://www.gnu.org/software/sed/manual/html_node/Multiple-commands-syntax.html 
sed -e "s/{{FQDN}}/${FQDN}/g" \
-e "s/{{NAME_LEGAL_NOTICE}}/${NAME_LEGAL_NOTICE}/g" \
-e "s/{{NAME_PRIVACY_POLICY}}/${NAME_PRIVACY_POLICY}/g" \
-e "s/{{FILENAME_LEGAL_NOTICE}}/${FILENAME_LEGAL_NOTICE}/g" \
-e "s/{{FILENAME_PRIVACY_POLICY}}/${FILENAME_PRIVACY_POLICY}/g" ${CUSTOMIZATIONS_PATH}/custom-frontend/${FQDN}/static/welcome.html > ${CUSTOMIZATIONS_PATH}/custom-frontend/${FQDN}/static/welcomePageAdditionalContent.html
rm ${CUSTOMIZATIONS_PATH}/custom-frontend/${FQDN}/static/welcome.html

ln -sf /usr/share/jitsi-meet/static/welcomePageAdditionalContent.html /var/www/jitsi-meet/${FQDN}/static/welcomePageAdditionalContent.html