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
CODEBLOCK=""

for DOMAIN in ${DOMAIN_LIST}
do
    # split string into parts  
    NUMBER_OF_PARTS=$(echo $DOMAIN | awk -F'\\.|\\:' '{ print NF }')

    SPLITTED_DOMAIN_STRING=$(echo $DOMAIN | awk -F'\\.|\\:' '{ for (i=1;i<=NF;i++) print $i }')

    # take parts as positional params  
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

# do the replacement in config file  
sed -e "s~{{CUSTOM_GROUPS}}~${CODEBLOCK}~g" ./coolwsd.xml.template > ./coolwsd.xml