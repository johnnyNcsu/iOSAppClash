#!/bin/bash
#
# Description: given a csv input file generated using Apple's Configurator application that
#   was used to generate a manifest of installed applications on an iPhone. The output is either
#   a key file or a hash file depending on the state of the -k command line switch.
#

source globals.sh

usage() {
    echo "Usage: ${0##*/} -i filename [-k] [-o filename]"
    echo "   where"
    echo "     -i  required input filename. This should be a csv file matching the format of application"
    echo "         lists exported by Apple's Configurator application."
    echo "     -k  when set, will generate a list of hash/key pairs for the installed 3rd party applications"
    echo "         on the device from which the export list came from."
    echo "     -o  optional base output filename. The base filename will be appended with the unique ID"
    echo "         for this device. The resulting output filename will be of the form:"
    printf '            <filename>_%.*s.txt\n' $UNIQUE_ID_FIELD_LEN 'UUUUUUUUUUUUUUUUUUUU'
    echo "               where"
    printf '                  %.*s is the first %d characters of the SHA256 hash of the UDID.\n' $UNIQUE_ID_FIELD_LEN 'UUUUUUUUUUUUUUUUUUUU' $UNIQUE_ID_FIELD_LEN
    echo "         If no filename is given, output will be to stdout."
    exit 2;
}

VALID_ARGS=$(getopt ki:o: $*)
if [ $? -ne 0 ]; then
    usage
fi

eval set -- "$VALID_ARGS"
karg="keygen=false"
oarg="fileout=stdout"

unset iarg

while :; do
  case "$1" in
    -i)
        if [[ "$2" == "-"* ]]; then
          echo "Missing required filename for option '-i' ..."
          usage
        fi

        iarg="$2"
        shift 2
        ;;
    -k)
        karg="keygen=true"
        shift
        ;;
    -o)
        if [[ "$2" == "-"* ]]; then
          echo "Missing required filename for option '-o' ..."
          usage
        fi

        oarg="fileout=$2"
        shift 2
        ;;

    --) shift;
        break
        ;;
  esac
done

if [ -n "$iarg" ]; then
    if [ ! -f "$iarg" ]; then
        echo "ERROR: input file not found: $iarg" >&2
        exit 2;
    fi
else
    echo "Missing required option and argument '-i filename' ..."
    usage
fi
#
# The awk script 4 key scetions:
# 1) the function hash generates a sha256 hash of the input string,
# 2) NR=1 reads in the column headings of the input csv file and determines if
#         it matches the expected format. If not, error out. The expected
#         input file format is that of an exported App list from Apple's
#         Configurator app version 2.16. Expected format is:
#            UDID,App Name,Seller
# 3) NR=2 record 2 should contain the UDID in column 1. The value is hased and
#         then used to construct the unique output filename for either the key
#         or hash files. The first app name and seller name are also on line 2
#         and used to populate the hash or key files as determined by the -k
#         switch.
# 4) otherwise process all remaining file records for output to hash or key file.
#

awk -v $karg -v $oarg -v uidlen=$UNIQUE_ID_FIELD_LEN -v hslen=$HASH_STRING_LEN \
    -v namelen=$IOS_NAME_LEN 'function hash(s, cmd, hex, line) {
   cmd = "openssl sha256 <<< \"" s "\""
   if ( (cmd | getline line) > 0)
      hex = line
   close(cmd)
   return hex
}
BEGIN {
   FS = ","
   OFS = "|"
}
NR == 1 {
   if (NF != 3) {
     print "ERROR: input file has incorrect format."
     exit
   } else {
     if ($1 != "UDID" || $2 != "App Name" || $3 != "Seller") {
       print "ERROR: input file has unexpected format."
       exit
     }
   }
   if (keygen == "true") {print "Generating hash keys ..."}
   else {print "Generating hashed list ..."}
   next
}
NR == 2 {
   ofile=fileout "_" substr(hash($1),1, uidlen) ".txt";
   split($2, subfield, "(");
   {gsub(/[[:space:]]+$/,"",subfield[1])};
   h[NR-1]=hash(subfield[1]);
   if (keygen == "true") {
     a[NR-1]=subfield[1];
     if (fileout == "stdout") {
       printf "%3d|%*s|% *s|\n", 1, hslen, h[NR-1], namelen, a[NR-1]
     } else {
       print "Writing keys to file " ofile
       printf "%3d|%*s|% *s|\n", 1, hslen, h[NR-1], namelen, a[NR-1] > ofile
     }
   } else {
     if (fileout == "stdout") {
       print h[NR-1]
     } else {
       print "Writing hashes to file " ofile
       print h[NR-1] > ofile
     }
   }
   next
}
{
   split($2, subfield, "(");
   {gsub(/[[:space:]]+$/,"",subfield[1])};
   h[NR-1]=hash(subfield[1]);
   if (keygen == "true") {
     a[NR-1]=subfield[1];
     if (fileout == "stdout") {
        printf "%3d|%*s|% *s|\n", NR-1, hslen, h[NR-1], namelen, a[NR-1]
     } else {
        printf "%3d|%*s|% *s|\n", NR-1, hslen, h[NR-1], namelen, a[NR-1] > ofile
     }
   } else {
     if (fileout == "stdout") {
       print h[NR-1]
     } else {
       print h[NR-1] > ofile
     }
   }
}' "$iarg"
