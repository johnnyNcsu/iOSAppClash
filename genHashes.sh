#!/bin/bash
usage() {
    echo "Usage: ${0##*/} -i filename [-k] [-p path] [-o filename]"
    echo "   where"
    echo "     -i  required input filename. This should be a csv file matching the format of application"
    echo "         lists exported by Apple's Configurator application."
    echo "     -k  when set, will generate a list of hash/key pairs for the installed 3rd party applications"
    echo "         on the device from which the export list came from."
    echo "     -p  allows setting the input/output file path. The default is the local working path."
    echo "     -o  optional base output filename. The base filename will be appended with the unique ID"
    echo "         for this device. The resulting outpout filename will be of the form:"
    echo "            <filename>_UUUUUU.txt"
    echo "               where"
    echo "                  UUUUUU  is the first 6 characters of the SHA256 hash of the UDID."
    echo "         If no filename is given, output will be to stdout."
    exit 2;
}

VALID_ARGS=$(getopt kp:i:o: $*)
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
    -p)
        if [[ "$2" == "-"* ]]; then
          echo "Missing required path for option '-p' ..."
          usage
        fi

        parg="$2"
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

awk -v $karg -v $oarg 'function hash(s, cmd, hex, line) {
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
   if (keygen == "true") { print "Generating hash keys ..."}
   else {print "Generating hashed list ..."}
   next
}
#
# The second line includes the device UDID in field 1.
# We will use a has of the UDID to uniquely name the output
# files, the keys and the shared hashes. The first six
# characters of the UDID hash are appended to each output file.
#
NR == 2 {
   ofile=fileout "_" substr(hash($1),1, 6) ".txt";
   split($2, subfield, "(");
   {gsub(/[[:space:]]+$/,"",subfield[1])};
   h[NR-1]=hash(subfield[1]);
   if (keygen == "true") {
     a[NR-1]=subfield[1];
     print "Writing keys to file " ofile
     print 1, h[NR-1], a[NR-1] > ofile
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
     print NR-1,h[NR-1], a[NR-1] > ofile
   } else {
     if (fileout == "stdout") {
       print h[NR-1]
     } else {
       print h[NR-1] > ofile
     }
   }
}' "$iarg"
