#!/bin/bash

# parameter expansion only works on BASH
# the default shell on Ubuntu/Debian is DASH, which not implemented param expansion.
# fix:
# echo "dash dash/sh boolean false" | debconf-set-selections
# DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

# don't overwrite $PATH! -> this var is used by system environment!
ENV_FILE=./jitsi.env
PARSE_FILE_IN=./cloud-config.template
PARSE_FILE_OUT=./cloud-config.yaml

if [ -f $ENV_FILE -a -f $PARSE_FILE_IN ]
then 
    # run line per line throug env file
    while read LINE_OF_FILE; 
    do 
        if [ -n "${LINE_OF_FILE}" ] # if not defined = empty
        then
            # {string:position:length}
            if [ ${LINE_OF_FILE:0:1} != "#" ] # check if not comment
            then
                # learning bash: parameter expansion
                # the result/match of expression is cutted to trash  
                # %: from the end of string, =: delimiter, *: everything  
                CONFIG_VAR=${LINE_OF_FILE%%=*} 
                CONFIG_VAR_VALUE="${LINE_OF_FILE#*=}" 

                if [ -z "${CONFIG_VAR_VALUE}" ]
                then
                    echo "Missing parameter for ${CONFIG_VAR}"
                    MISSING_VAR=true
                else
                    SED_PATTERN="${SED_PATTERN}-e \"s~{{${CONFIG_VAR}}}~${CONFIG_VAR_VALUE}~g\" "
                fi
               
            else
                continue
            fi
        else
            continue
        fi;
    done < $ENV_FILE # source the file to the function upstream  
    
    if [ -z ${MISSING_VAR} ]
    then
        # execute pattern and write to FILE
        SED_CMD="sed ${SED_PATTERN} ${PARSE_FILE_IN}"
        eval "${SED_CMD}" > ${PARSE_FILE_OUT}

        if [ "$?" = "0" ]
        then
            echo "OK! Configuration file - ${PARSE_FILE_OUT} - successfully built."
            exit 0
        else
            echo "An error occured!"
            exit 1
        fi

    else
        echo "First add the missing params in your - ${ENV_FILE} - before you continue."
        exit 1
    fi 

else  
    echo "No file(s) found!"
    exit 1
fi