#!/bin/bash
# This script is designed to compare hashed app lists from different iPhones
# to determine if phones have common apps installed.
#
# This script assumes that the user has already generated their hashed upload
# and key lists and downloaded hashed lists from other participating users from
# the designated cloud share upload repository.

# Check for the locally generated hash and key files. The key file will have the
# form: 
#   KEY_FILE_OFF='./keyAppList\_[[:alnum:]]{6}\.txt'
#
# We construct that by seperating its constituent parts as follows:

KEY_FILE_PATH='./'
KEY_FILE_PREFIX='keyAppList'
KEY_FILE_DELIMITER='_'
UNIQUE_ID_REGEX='[[:alnum:]]{6}'
KEY_FILE_SUFFIX='.txt'

UPLOAD_FILE_PATH=$KEY_FILE_PATH
UPLOAD_FILE_PREFIX='upload'
UPLOAD_FILE_DELIMITER=$KEY_FILE_DELIMITER
UPLOAD_FILE_SUFFIX=$KEY_FILE_SUFFIX
HASH_FILE="./hashAppList.txt"
UPLOAD_FILE='./upload\_[[:alnum:]]{6}\.txt'

# and then adding the parts together as so:

KEY_FILE="${KEY_FILE_PATH}${KEY_FILE_PREFIX}\\${KEY_FILE_DELIMITER}${UNIQUE_ID_REGEX}\\${KEY_FILE_SUFFIX}"

# We do this because we are primarily interested in recovering the six character
# UNIQUE_ID that follows the '_' delimiter in the file name. To find the users
# UNIQUE_ID, we first locate the key files by finding files that match our regex.

IFS=$'\n' read -r -d '' -a keyFilenames <<< "$(find -E . -regex $KEY_FILE)"

#
# Recover the number of files found matching our regex. Ideally this will be 1.
#

keyFilenames_array_len="${#keyFilenames[@]}"

#
# We can't proceed if we don't find a match.
#

if [ $keyFilenames_array_len == 0 ]
then
  >&2 printf 'ERROR: key file not found! File name must match regular expression: %s\n' "${KEY_FILE}"
  exit 1
fi

#
# With at least one key file found, we can recover the hashed unique ID by selecting
# the six characters between the '_' delimiter and the '.' before the prefix.
#

IFS=' ' read hashedUDID <<< $(awk -F '_' 'FNR==1 { split($2, subfield, "."); print subfield[1]; next}' <<< ${keyFilenames[0]})

if [ $keyFilenames_array_len == 1 ]
then
    #awk -F '_' 'FNR==1 { split($2, subfield, "."); print "keyAppList_" $2 ","  subfield[1]; next}' <<< $keyFilenames
#    IFS=' ' read strippedKeyName hashedUDID <<< $(awk -F '_' 'FNR==1 { split($2, subfield, "."); print "keyAppList_" $2 " " subfield[1]; next}' <<< $keyFilenames)
    echo "Key file found:" ${KEY_FILE_PREFIX}${KEY_FILE_DELIMITER}${hashedUDID}${KEY_FILE_SUFFIX}
else
    echo "WARNING: multiple key files found! Using:" ${KEY_FILE_PREFIX}${KEY_FILE_DELIMITER}${hashedUDID}${KEY_FILE_SUFFIX}
fi

echo "Local unique identifier:" $hashedUDID 
LOCAL_UPLOAD_FILE="${KEY_FILE_PATH}${UPLOAD_FILE_PREFIX}${UPLOAD_FILE_DELIMITER}${hashedUDID}${UPLOAD_FILE_SUFFIX}"

# Build array of all filenames in current directory matching the names of the form:
#      <upload_><AAAAAA><.txt>
#           where:
#               upload_ is the ASCII name prefix followed by the UDID delimiter.
#               AAAAAA  is the fist six characters of the hash of the UDID from which the
#                       app list was generated.
#               .txt    is the filetype extension.
#

UPLOAD_FILE="${UPLOAD_FILE_PATH}${UPLOAD_FILE_PREFIX}\\${UPLOAD_FILE_DELIMITER}${UNIQUE_ID_REGEX}\\${UPLOAD_FILE_SUFFIX}"

# Load filenames matching regex into array UPLOAD_FILE_ARRAY

IFS=$'\n' read -r -d '' -a UPLOAD_FILE_ARRAY <<< "$(find -E . -regex $UPLOAD_FILE)"

# Get total number of files found.

UPLOAD_FILE_ARRAY_LEN="${#UPLOAD_FILE_ARRAY[@]}"

if [ $UPLOAD_FILE_ARRAY_LEN == 0 ]
then
    echo "No upload files to compare. Done."
    exit 1
fi

echo "Number of upload files:" $UPLOAD_FILE_ARRAY_LEN
for eachfile in ${UPLOAD_FILE_ARRAY[@]}
do
   if [ $LOCAL_UPLOAD_FILE == $eachfile ]
   then
      echo "Skipping local file: $eachfile"
   else
      echo "Comparing file: $eachfile ..."
   fi
done
