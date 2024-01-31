#!/bin/bash
# This script is designed to compare hashed app lists from different iPhones
# to determine if phones have common apps installed.
#
# This script assumes that the user has already generated their hashed upload
# and key lists and downloaded hashed lists from other participating users from
# the designated cloud share upload repository.

# Check for the locally generated hash and key files. The key file will have the
# form: 
#   KEY_FILE='./keyAppList\_[[:alnum:]]{6}\.txt'
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

MATCH_FILE_PATH=$KEY_FILE_PATH
MATCH_FILE_PREFIX='match'
MATCH_FILE_DELIMITER=$KEY_FILE_DELIMITER
MATCH_FILE_SUFFIX=$KEY_FILE_SUFFIX

# and then adding the parts together as so:

KEY_FILE="${KEY_FILE_PREFIX}\\${KEY_FILE_DELIMITER}${UNIQUE_ID_REGEX}\\${KEY_FILE_SUFFIX}"

# We left the path off the KEY_FILE string becuase it makes it more readable when
# printing for later use. The path string will be added as needed later.

# We build the string this way because we are interested in recovering the six character
# UNIQUE_ID that follows the '_' delimiter in the file name. To find the users
# UNIQUE_ID, we first locate the key files by finding files that match our regex.

IFS=$'\n' read -r -d '' -a keyFilenames <<< "$(find -E . -regex ${KEY_FILE_PATH}${KEY_FILE})"

#
# Recover the number of files found matching our regex. Ideally this will be 1.
#

keyFilenames_array_len="${#keyFilenames[@]}"

#
# We can't proceed if we don't find a match.
#

if [ $keyFilenames_array_len == 0 ]
then
  >&2 printf 'ERROR: key file not found! File name must match regular expression: %s\n' "${KEY_FILE_PATH}${KEY_FILE}"
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
    LOCAL_KEY_FILE=${KEY_FILE_PREFIX}${KEY_FILE_DELIMITER}${hashedUDID}${KEY_FILE_SUFFIX}
    echo "Key file found: ${LOCAL_KEY_FILE}"
#    LOCAL_KEY_FILE=${KEY_FILE_PATH}${LOCAL_KEY_FILE}
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
      IFS=' ' read hashedUDID <<< $(awk -F '_' 'FNR==1 { split($2, subfield, "."); print subfield[1]; next}' <<< $eachfile]})
      MATCH_FILE=${MATCH_FILE_PREFIX}${MATCH_FILE_DELIMITER}${hashedUDID}${MATCH_FILE_SUFFIX}
      awk -v filein=$LOCAL_KEY_FILE -v fileout=$MATCH_FILE 'BEGIN {FS = "|"; count=0}
          NR==FNR {keys[$2]=$3; next}
          {if ($0 in keys) {if (count==0) {print "Matches with keyfile:", filein > fileout}; {count+=1; print count, $0, keys[$0] > fileout}}}
      END {if (count>0) {print "Writing", count, "matches to:", fileout; exit}
           else {print "No matches found"}}' $LOCAL_KEY_FILE $eachfile
   fi
done

MATCH_FILE=${MATCH_FILE_PREFIX}\\${MATCH_FILE_DELIMITER}${UNIQUE_ID_REGEX}\\${MATCH_FILE_SUFFIX}
IFS=$'\n' read -r -d '' -a matchFilenames <<< "$(find -E . -regex ${MATCH_FILE_PATH}${MATCH_FILE})"
matchFilenames_array_len="${#matchFilenames[@]}"

#
# If we find no matches, we're done.
#

if [ $matchFilenames_array_len == 0 ]
then
  >&1 printf 'No matches found in compared files. Nothing else to do.'
  exit 1
fi

echo "Local device contains matching applications on $matchFilenames_array_len other device(s)."

#
# If we find only 1 device with matches, we are also done.
#

if [ $matchFilenames_array_len == 1 ]
then
  >&1 printf 'Matches found on single device are listed in output file: %s\n' "${matchFilenames[0]}"
  exit 1
fi

#
# With multiple matches, we can histogram results to see if any apps pop out ...
#

echo "Histograming results:"

for eachfile in ${matchFilenames[@]}
do
  echo "Analyzing file: $eachfile ..."
  IFS=' ' read hashedUDID <<< $(awk -F '_' 'FNR==1 { split($2, subfield, "."); print subfield[1]; next}' <<< $eachfile]})
  echo "Histograming applications for device: $hashedUDID"
#  MATCH_FILE=${MATCH_FILE_PREFIX}${MATCH_FILE_DELIMITER}${hashedUDID}${MATCH_FILE_SUFFIX}
#  awk -v filein=$LOCAL_KEY_FILE -v fileout=$MATCH_FILE 'BEGIN {FS = "|"; count=0}
#      NR==FNR {keys[$2]=$3; next}
#      {if ($0 in keys) {if (count==0) {print "Matches with keyfile:", filein > fileout}; {count+=1; print count, $0, keys[$0] > fileout}}}
#  END {if (count>0) {print "Writing", count, "matches to:", fileout; exit}
#       else {print "No matches found"}}' $LOCAL_KEY_FILE $eachfile
done 

