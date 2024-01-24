#!/bin/sh
#
# This script is design to do two things:
# 1) simplify creation of both the hashed app list and the hash key files, and
# 2) ensure a consistent naming convention for the upload and key files to simplify
#    operation in the comparison stage and possible an auto-fetch operation.
#

#KEY_FILE_PATH='./'
KEY_FILE_PREFIX='keyAppList'
#KEY_FILE_DELIMITER='_'
#UNIQUE_ID_REGEX='[[:alnum:]]{6}'
#KEY_FILE_SUFFIX='.txt'

#UPLOAD_FILE_PATH=$KEY_FILE_PATH
UPLOAD_FILE_PREFIX='upload'
#UPLOAD_FILE_DELIMITER=$KEY_FILE_DELIMITER
#UPLOAD_FILE_SUFFIX=$KEY_FILE_SUFFIX

usage() {
    >&2 printf 'Usage: ./%s file.csv\n' "${0##*/}"
    >&2 printf '   where file.csv is the name of the file exported from the Configurator tool.\n'
    exit 1
}

#UPLOAD_FILE="${UPLOAD_FILE_PATH}${UPLOAD_FILE_PREFIX}\\${UPLOAD_FILE_DELIMITER}${UNIQUE_ID_REGEX}\\${UPLOAD_FILE_SUFFIX}"

if [ -f "$1" ] ; then
    case $1 in
        *.csv|*.CSV)
            ./genhashes.sh -i "$1" -o "$UPLOAD_FILE_PREFIX"
            ./genhashes.sh -i "$1" -k -o "$KEY_FILE_PREFIX"
            ;;
        *)
            usage
    esac
else
    usage
fi
