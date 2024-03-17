#!/bin/sh  

# be aware that your vars are set and your .env is loaded ..
# remember: the env file is build from your cloud-config.yml  
# remember: set values for vars (for this script) in your env file  
APP_PATH=${1:-'/opt/apps/collabora'}
. ${APP_PATH}/.env

##############################################################################
# Register domain and alias pattern for coolwsd.xml (group-block)  
# The domain-strings (like 'subdomain.domain.tld:port') are defined in your 
# .env file. Every domain-string is parsed to its components and added as its
# own 'group'-block in coolwsd.xml.  
##############################################################################

# Get list with domain-strings from second parameter $2
# If no param given it checks first if there is already a param 'DOMAIN_LIST' 
# (i.e. defined in global env). 
# If param is missing and no 'DOMAIN_LIST' is defined it stops with error.  
# 
# Every entry must consist as follows: subdomain.domain.tld:port  
DOMAIN_LIST=${2:-${DOMAIN_LIST:?'no parameter given!'}}

# Your CODEBLOCK to register allowed servers (in groups) is generated automatically.  
# This var should be empty but declared at the beginning.  
CODEBLOCK=""

for DOMAIN in ${DOMAIN_LIST}
do
    # split string into parts  
    NUMBER_OF_PARTS=$(echo $DOMAIN | awk -F'\\.|\\:' '{ print NF }')

    # you get the pattern: 'subdomain domain tld port' (separated by white spaces)  
    SPLITTED_DOMAIN_STRING=$(echo $DOMAIN | awk -F'\\.|\\:' '{ for (i=1;i<=NF;i++) print $i }')

    # take parts as positional params (1..4)  
    set -- ${SPLITTED_DOMAIN_STRING}

    # assign parts to placeholders  
    SUBDOMAIN=$1
    DOMAIN=$2
    TLD=$3
    PORT=$4

    # build PREFORMATED code string  
    CODE_FRAGMENT="\<group>\\n                <host desc=\"hostname to allow or deny.\" allow=\"true\">https:\/\/${SUBDOMAIN}.${DOMAIN}.${TLD}:${PORT}\<\/host>\\n                <alias desc=\"regex pattern of aliasname\">https:\/\/${SUBDOMAIN}[0-9]{1}\\\.${DOMAIN}\\\.${TLD}:${PORT}\<\/alias>\\n            </group>"
    CODEBLOCK="${CODEBLOCK}${CODE_FRAGMENT}\\n            "
done

# replaces with the placeholder/default if var(s) is empty  
CODEBLOCK=${CODEBLOCK:-'{{CUSTOM_GROUPS}}'}
CUSTOM_REMOTE_FONTS_URL=${CUSTOM_REMOTE_FONTS_URL:-'{{CUSTOM_REMOTE_FONTS_URL}}'}

# do the replacement in config file  
sed -e "s~{{CUSTOM_GROUPS}}~${CODEBLOCK}~g" \
-e "s~{{CUSTOM_REMOTE_FONTS_URL}}~${CUSTOM_REMOTE_FONTS_URL}~g" ${APP_PATH}/coolwsd.xml.template > ${APP_PATH}/coolwsd.xml

##############################################################################
# *** CUSTOM HTML ***
# get your custom html files   
# remember: curl -f : fails silenty -o writes source file to destination filename  
##############################################################################

# mkdir -p /var/www/collabora/html/
# directory already created in write_files section

# create folders and get files  
mkdir -p ${APP_PATH}/html
mkdir -p ${APP_PATH}/html/css
curl -fo ${APP_PATH}/html/legal-notice_de.html "https://raw.githubusercontent.com/netzwerkproduktioner/corporate-public/main/web/default/html/legal-notice/legal-notice_de.html"
curl -fo ${APP_PATH}/html/privacy-policy_de.html "https://raw.githubusercontent.com/netzwerkproduktioner/corporate-public/main/web/default/html/privacy-policy/privacy-policy_de.html"
curl -fo ${APP_PATH}/html/favicon.ico "https://raw.githubusercontent.com/netzwerkproduktioner/corporate-public/main/web/default/images/favicon.ico"
curl -fo ${APP_PATH}/html/css/styles.css "https://raw.githubusercontent.com/netzwerkproduktioner/corporate-public/main/web/default/css/styles.css"

# move css to destination folder  
mv -f ${APP_PATH}/html/css/ /var/www/collabora/html/

# renaming and parsing legal-notice to destination folder  
# depending on your settings in your .env file  
sed -e "s/{{FILENAME_LEGAL_NOTICE}}/${FILENAME_LEGAL_NOTICE}/g" \
-e "s/{{FILENAME_PRIVACY_POLICY}}/${FILENAME_PRIVACY_POLICY}/g" ${APP_PATH}/html/legal-notice_de.html > /var/www/collabora/html/${FILENAME_LEGAL_NOTICE}
rm ${APP_PATH}/html/legal-notice_de.html

# move and rename privacy-policy  
mv -f ${APP_PATH}/html/privacy-policy_de.html /var/www/collabora/html/${FILENAME_PRIVACY_POLICY}

# move the other files and cleanup
mv -f ${APP_PATH}/html/* /var/www/collabora/html
rm -R ${APP_PATH}/html