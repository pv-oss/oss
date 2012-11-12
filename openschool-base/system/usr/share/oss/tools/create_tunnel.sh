#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

if [ "$1" = "--help" -o  "$1" = "-h" ]
then
	echo 'Usage: /usr/share/oss/tools/create_tunnel.sh [OPTION]'
	echo 'Script to setup ssh-service-tunnel to the EXTIS service server.'
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
	echo '	create_tunnel.sh'
	echo 'DESCRIPTION:'
	echo '	Script to setup ssh-service-tunnel to the EXTIS service server.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	exit
fi

. /etc/sysconfig/schoolserver
HN=$( hostname -f )
TMP=$(wget -O - "http://repo.openschoolserver.net:/cgi-bin/create-tunnel.pl?regcode=$SCHOOL_REG_CODE&fqhn=$HN" 2> /dev/null )
echo $TMP
PORT=$(echo $TMP | gawk 'BEGIN { FS = "#" } /###/ { print $4 }')
SSHK=$(echo $TMP | gawk 'BEGIN { FS = "#" } /###/ { print $5 }')

grep "$SSHK" /root/.ssh/authorized_keys || echo "$SSHK" >> /root/.ssh/authorized_keys

echo 'Das Passwort lautet "ssh-tunnel-user"'
ssh -R $PORT:localhost:22 -p 443 tunnel@pan.extis.de

sed -i '/tunnel@extis/d' /root/.ssh/authorized_keys
