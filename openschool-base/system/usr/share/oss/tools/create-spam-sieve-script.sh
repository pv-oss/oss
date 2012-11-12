#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

if [ "$1" = "--help" -o  "$1" = "-h" ]
then
	echo 'Usage: /usr/share/oss/tools/create-spam-sieve-script.sh [OPTION]'
	echo 'Leiras .....'
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
	echo '	create-spam-sieve-script.sh'
	echo 'DESCRIPTION:'
	echo '	Leiras ....'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	exit
fi

PASSWD=`/usr/sbin/oss_get_admin_pw`
for i in `ldapsearch -x -LLL '(&(objectclass=schoolAccount)(mailenabled=OK))' uid | grep uid: | sed 's/uid: //'`
do
        /usr/share/oss/tools/oss_sieveshell -p $PASSWD -u $i -a cyrus -e "put /usr/share/oss/templates/spam"  mailserver:2000
        /usr/share/oss/tools/oss_sieveshell -p $PASSWD -u $i -a cyrus -e "activate spam"  mailserver:2000
        echo "Done $i"
done
