#!/bin/sh
#
# This script is design to do two things:
# 1) simplify creation of both the hashed app list and the hash key files, and
# 2) ensure a consistent naming convention for the upload and key files to simplify
#    operation in the comparison stage and possible an auto-fetch operation.
#

source defaults.sh

usage() {
    >&2 printf 'Usage: ./%s file.csv\n' "${0##*/}"
    >&2 printf '   where file.csv is the name of the file exported from the Configurator tool.\n'
    exit 1
}

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
