#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

if [ "$1" = "--help" -o  "$1" = "-h" ]
then
	echo 'Usage: /usr/share/oss/tools/recreate_group_directories.sh [OPTION]'
	echo "This script recreates the user's home directory."
	echo
	echo 'Options :'
	echo 'Mandatory parameters :'
	echo "		No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo 'Optional parameters :'
	echo '		-h,   --help         Display this help.'
	echo '		-d,   --description  Display the descriptiont.'
	exit
fi

if [ "$1" = "--description" -o  "$1" = "-d" ]
then
	echo 'NAME:'
	echo '	recreate_group_directories.sh'
	echo 'DESCRIPTION:'
	echo "	This script recreates the user's home directory."
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	exit
fi

mkdir -p /home/groups
cd /home/groups
for i in `ldapsearch -LLL -x objectclass=schoolgroup cn | grep cn: | sed 's/cn: //'`; do   mkdir $i; chgrp $i $i; chmod 2770 $i; setfacl -d -m g::rwx $i; done
test -e /home/groups/WORKSTATIONS && rm -r /home/groups/WORKSTATIONS
test -e /home/groups/workstations && rm -r /home/groups/workstations

cd
