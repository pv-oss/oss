#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

if [ "$1" = "--help" -o  "$1" = "-h" ]
then
        echo 'Usage: /usr/share/oss/tools/scan-home.sh'
        echo 'Scan /home for viruses and save the result into /var/log/virus_scan_logs/<Date_Time>'
        echo
        echo 'Options :'
        echo 'Mandatory parameters :'
        echo "          No need for mandatory parameters. (There's no need for parameters for running this script.)"
        echo 'Optional parameters :'
        echo '          -h,   --help         Display this help.'
        echo '          -d,   --description  Display the descriptiont.'
        exit
fi

if [ "$1" = "--description" -o  "$1" = "-d" ]
then
        echo 'NAME:'
        echo '  scan-home.sh'
        echo 'DESCRIPTION:'
        echo '  Scan /home for viruses and save the result into /var/log/virus_scan_logs/<Date_Time>'
        echo 'PARAMETERS:'
        echo '  MANDATORY:'
        echo "                              : No need for mandatory parameters. (There's no need for parameters for running this script.)"
        echo '  OPTIONAL:'
        echo '          -h,   --help        : Display this help.(type=boolean)'
        echo '          -d,   --description : Display the descriptiont.(type=boolean)'
        exit
fi

/usr/bin/clamscan --move=/tmp/VIRUS -r /home | grep 'FOUND\|OK' > /var/log/virus_scan_logs/$(date +%Y-%m-%d_%T).log

