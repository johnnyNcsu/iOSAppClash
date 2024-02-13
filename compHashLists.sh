#!/bin/bash
# This script is designed to compare hashed app lists from different iPhones
# to determine if phones have common apps installed.
#
# This script assumes that the user has already generated their hashed upload
# and key lists and downloaded hashed lists from other participating users from
# the designated cloud share upload repository.

source globals.sh

usage() {
    echo
    echo "Usage: ${0##*/} [-c] [-k] [-l] [-pN]"
    echo "   where"
    echo "     -c  when set, histogram bars will be constructed using the character X to represent a"
    echo "         device with the designated app installed. When not set, histogram bars will be"
    echo "         constructed using the unique ID of the device with the designated app installed."
    echo "     -k  when set, will keep intermediate match files. The default is to remove them when no"
    echo "         longer needed."
    printf '     -l  long output. When set, will include %d character long hash values in histogram output\n' $HASH_STRING_LEN
    echo "         file."
    echo "     -pN prune output to include only the N highest scoring records sorted from highest to"
    echo "         lowest scores. Use -p+ to output all records from highest to lowest scores."
    echo
    exit 2;
}

VALID_ARGS=$(getopt cklp: $*)
if [ $? -ne 0 ]; then
    usage
fi

eval set -- "$VALID_ARGS"
carg="charhist=false"
unset karg
unset larg
unset parg

FIELD_1_HEADER="CNT"

while :; do
  case "$1" in
    -c)
        carg="charhist=true"
        shift
        ;;

    -k)
        karg="keep=true"
        shift
        ;;

    -l)
        larg="trim=false"
        shift
        ;;

    -p)
        if ! [[ "$2" =~ (^[0-9]{1,}$) || "$2" == "+" ]]; then
          echo "ERROR: prune value must be an integer or the '+' character."
          usage
        fi
        parg="pruneval=$2"
        FIELD_1_HEADER="SCR"
        shift 2
        ;;

    --) shift;
        break
        ;;
  esac
done

# Check for the locally generated hash and key files. The key file will have the
# form (assumes $UNIQUE_ID_FIELD_LEN=6): 
#   KEY_FILE='./keyAppList\_[[:alnum:]]{6}\.txt'
#
# We construct that by seperating its constituent parts as follows:

KEY_FILE_PATH='./'
KEY_FILE_PREFIX='keyAppList'
KEY_FILE_DELIMITER='_'
UNIQUE_ID_REGEX='[[:alnum:]]{'$UNIQUE_ID_FIELD_LEN'}'
KEY_FILE_SUFFIX='.txt'

UPLOAD_FILE_PATH=$KEY_FILE_PATH
UPLOAD_FILE_PREFIX='upload'
UPLOAD_FILE_DELIMITER=$KEY_FILE_DELIMITER
UPLOAD_FILE_SUFFIX=$KEY_FILE_SUFFIX
HASH_FILE="./hashAppList.txt"

MATCH_FILE_PATH=$KEY_FILE_PATH
MATCH_FILE_PREFIX='match'
MATCH_FILE_DELIMITER=$KEY_FILE_DELIMITER
MATCH_FILE_SUFFIX=$KEY_FILE_SUFFIX

HISTOGRAM_FILE_PATH=$KEY_FILE_PATH
HISTOGRAM_FILE_PREFIX='histogram'
HISTOGRAM_FILE_DELIMITER=$KEY_FILE_DELIMITER
HISTOGRAM_FILE_SUFFIX=$KEY_FILE_SUFFIX
HISTOGRAM_BAKUP_SUFFIX='.bak'
HISTOGRAM_BAKUP_FILE=$HISTOGRAM_FILE_PREFIX
HISTOGRAM_BAKUP_ORDINAL_REGEX='[[:digit:]]{1,2}'
HISTOGRAM_TMP_DESIGNATOR='tmp'
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

IFS=' ' read localUDID <<< $(awk -F '_' 'FNR==1 { split($2, subfield, "."); print subfield[1]; next}' <<< ${keyFilenames[0]})
LOCAL_KEY_FILE=${KEY_FILE_PREFIX}${KEY_FILE_DELIMITER}${localUDID}${KEY_FILE_SUFFIX}

if [ $keyFilenames_array_len == 1 ]
then
    echo "Key file found: ${LOCAL_KEY_FILE}"
else
    echo "WARNING: multiple key files found! Using:" ${LOCAL_KEY_FILE}
fi

echo "Local unique identifier:" $localUDID 
LOCAL_UPLOAD_FILE="${KEY_FILE_PATH}${UPLOAD_FILE_PREFIX}${UPLOAD_FILE_DELIMITER}${localUDID}${UPLOAD_FILE_SUFFIX}"

# Build array of all filenames in current directory matching the names of the form (assumes $UNIQUE_ID_FIELD_LEN
# is set to 6 which governs the length of the unique ID field):
#      <upload_><UUUUUU><.txt>
#           where:
#               upload_ is the ASCII name prefix followed by the UDID delimiter.
#               UUUUUU  is the fist six characters (for example) of the hash of the UDID from which the
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
      IFS=' ' read hashedUDID <<< $(awk -F '_' 'FNR==1 { split($2, subfield, "."); print subfield[1]; next}' <<< $eachfile})
      MATCH_FILE=${MATCH_FILE_PREFIX}${MATCH_FILE_DELIMITER}${hashedUDID}${MATCH_FILE_SUFFIX}
      awk -v fileout=$MATCH_FILE 'BEGIN {FS = "|"; count=0}
          NR==FNR {keys[$2]=$3; next}
          {if ($0 in keys) {count+=1; print $0 > fileout}}
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
  >&1 printf 'No matches found in compared files. Nothing else to do.\n'
  exit 1
fi

echo "Local device contains matching applications on $matchFilenames_array_len other device(s)."

#
# With one or more matches, we can histogram results ...
#

echo "Histograming results:"

#
# The local key file is the initial histogram result - the list of installed apps on the
# local device.
#

HISTOGRAM_FILE=${HISTOGRAM_FILE_PREFIX}${HISTOGRAM_FILE_SUFFIX}

if [ -f "$HISTOGRAM_FILE" ]; then
  read -p "WARNING: found previous histogram file! Overwrite (y/n)? " answer
  case ${answer:0:1} in
    y|Y)
       echo "Overwrting existing histogram file."
       rm $HISTOGRAM_FILE
    ;;
    * )
       HISTOGRAM_BAKUP_FILE=${HISTOGRAM_FILE_PREFIX}${HISTOGRAM_BAKUP_SUFFIX}
       if [ -f "$HISTOGRAM_BAKUP_FILE" ]; then
         IFS=$'\n' read -r -d '' -a histogramBakupFiles <<< "$(find -E . -regex ${HISTOGRAM_FILE_PATH}${HISTOGRAM_FILE_PREFIX}${HISTOGRAM_BAKUP_ORDINAL_REGEX}\\${HISTOGRAM_BAKUP_SUFFIX})"
         histogramBakupFiles_array_len="${#histogramBakupFiles[@]}"
         printf -v HISTOGRAM_BAKUP_FILE '%s%d%s' "$HISTOGRAM_FILE_PREFIX" "$((histogramBakupFiles_array_len+2))" "$HISTOGRAM_BAKUP_SUFFIX"
       fi
       echo "Moving $HISTOGRAM_FILE to $HISTOGRAM_BAKUP_FILE"
       mv "$HISTOGRAM_FILE" "$HISTOGRAM_BAKUP_FILE"
    ;;
  esac
fi

cp $LOCAL_KEY_FILE $HISTOGRAM_FILE

#
# Iterate over each match file looking for matched hashes and appending the udid of
# a foreign device to the matched hash record. Repeat this process for each match file
# forming a histogram of udid's where app matches occur.
#

HISTOGRAM_TMP_FILE="${HISTOGRAM_FILE_PREFIX}${HISTOGRAM_FILE_DELIMITER}${HISTOGRAM_TMP_DESIGNATOR}${HISTOGRAM_FILE_SUFFIX}"

for eachfile in ${matchFilenames[@]}
do
  echo "Analyzing file: $eachfile ..."
  IFS=' ' read hashedUDID <<< $(awk -F '_' 'FNR==1 { split($2, subfield, "."); print subfield[1]; next}' <<< $eachfile})
  echo "Histograming applications for device: $hashedUDID"
  awk -v fileout=$HISTOGRAM_TMP_FILE -v udid=$hashedUDID 'BEGIN {FS = "|"; OFS=""}
      NR==FNR {hashes[$0]=0; next}
      {if ($2 in hashes) {print $0,udid,"|" > fileout}
       else { print $0 > fileout}}' $eachfile $HISTOGRAM_FILE

#
# Remove the old histogram file and replace it with the temporary histogram just written.
#

  rm $HISTOGRAM_FILE
  mv $HISTOGRAM_TMP_FILE $HISTOGRAM_FILE

#
# If -k option is not set, remove the intermediate match files.
#

  if [ ! -n "$karg" ]; then
    echo "Removing intermediate file: $eachfile"
    rm $eachfile
  fi

done 

# At this point, we have a raw output file with a full histogram built with unique
# device IDs. From here, we can tailor the output to the users desired needs.

if [ -n "$parg" ]; then

# In order to prune the results, we must first sort the records in order of highest
# score first. Pre-prend the score of each record to the output string.

  echo "Pruning results ..."
  awk -v fileout=$HISTOGRAM_TMP_FILE 'BEGIN {FS = "|"; OFS=""}
     { printf "%3d|%s\n", NF-4, $0 > fileout }' $HISTOGRAM_FILE

# Next, sort the records in reverse order.

  sort -r -k1 -t "|" -o $HISTOGRAM_FILE $HISTOGRAM_TMP_FILE

# If user selected to include all histogram scores (pruneval=+), then set the
# numeric value of pruning equal to the total number of apps on local device
# as determined by the number of records in the histogram file at this point.

  if [[ "$parg" == "pruneval=+" ]]; then
    IFS=' ' read parg <<< $(echo "pruneval="$(cut -d " " -f1 <<< $(wc -l $HISTOGRAM_FILE)))
  fi

# Next, preserve the top N scores. At this step, also delete the ordinal app count
# which carries little meaning now. It is replaced by the histogram score.

  awk -v fileout=$HISTOGRAM_TMP_FILE -v $parg 'BEGIN {FS = "|"; OFS=""}
     NR==1 { count=1; score=$1; print $1 substr($0,8)  > fileout }
     { if (score == $1) print $1 substr($0,8)  > fileout
       else { count++; score=$1;
         if ( count > pruneval ) exit 1}}' $HISTOGRAM_FILE
else

# Not pruning, copy histogram output to tmp file.

  mv $HISTOGRAM_FILE $HISTOGRAM_TMP_FILE

fi

#
# If -l option is not set, trim the final result of hashes for readability otherwise
# leave the hashed app names in for long output.
#

if [ ! -n "$larg" ]; then
  echo "Removing hashes from final result ..."
  awk -v fileout=$HISTOGRAM_FILE -v namelen=$IOS_NAME_LEN -v uidlen=$UNIQUE_ID_FIELD_LEN -v $carg -v header1=$FIELD_1_HEADER 'BEGIN {FS = "|"; OFS=""}
     NR==1 { if (charhist == "true") {
               printf "%s|% *s| Histogram Showing Number of Devices With The Named Application Installed\n", \
               header1, namelen, "  App Names on Local Device   " > fileout;
             } else {
               printf "%s|% *s| Histogram of %d Character Unique IDs of Devices With The Named Application Installed\n", \
               header1, namelen, "  App Names on Local Device   ", uidlen > fileout;
             }
             print "---|------------------------------|------------------------------------------------------------------------------------"\
               > fileout}
     { if (charhist == "true") {
         printf "%s|%s|", $1, $3 > fileout;
         for ( i=4; i < NF; i++ ) printf "%s", "X" > fileout; printf"\n" > fileout
       } else { print $1 substr($0, index($0,$2)+length($2)) > fileout; next}}' $HISTOGRAM_TMP_FILE
else
  awk -v fileout=$HISTOGRAM_FILE -v hashlen=$HASH_STRING_LEN -v namelen=$IOS_NAME_LEN -v uidlen=$UNIQUE_ID_FIELD_LEN -v $carg -v header1=$FIELD_1_HEADER 'BEGIN {FS = "|"; OFS=""}
     NR==1 { if (charhist == "true") {
               printf "%s|%.*s|% *s| Histogram Showing Number of Devices With The Named Application Installed\n",\
               header1, hashlen, "                    Hash of App Name                            ", namelen, "  App Names on Local Device   "\
               > fileout;
             } else {
               printf "%s|%.*s|% *s| Histogram of %d Character Unique IDs of Devices With The Named Application Installed\n",\
               header1, hashlen, "                    Hash of App Name                            ", namelen, "  App Names on Local Device   ",\
               uidlen > fileout;
             }
             print "---|----------------------------------------------------------------|------------------------------|------------------------------------------------------------------------------------" > fileout}
     { if (charhist == "true") {
         printf "%s|%s|%s|", $1, $2, $3 > fileout;
         for ( i=4; i < NF; i++ ) printf "%s", "X" > fileout; printf"\n" > fileout
     } else { print $0 > fileout; next}}' $HISTOGRAM_TMP_FILE
fi

echo "Analysis results written to file: $HISTOGRAM_FILE"
