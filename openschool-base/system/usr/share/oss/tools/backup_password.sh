#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

usage ()
{
	echo 'Usage: /usr/share/oss/tools/backup_password.sh [OPTION]'
	echo 'Makes easy recoverable backup files from users passwort attributes'
	echo 'The created files are: /tmp/<uid>-*Password'
	echo 'You can recover these with the commands:'
	echo '	oss_ldapmodify < /tmp/<uid>-sambaNTPassword'
	echo '	oss_ldapmodify < /tmp/<uid>-sambaLMPassword'
	echo '	oss_ldapmodify < /tmp/<uid>-userPassword'
	echo
	echo 'Mandatory parameters :'
	echo "		--uid                User name'"
	echo 'Optional parameters :'
	echo '		-h,   --help         Display this help.'
	echo '		-d,   --description  Display the descriptiont.'
}

description ()
{
	echo 'NAME:'
	echo '	backup_password.sh'
	echo 'DESCRIPTION:'
	echo '	Makes easy recoverable backup files from users passwort attributes'
	echo '	The created files are: /tmp/<uid>-*Password'
	echo '	You can recover these with the commands:'
	echo '		oss_ldapmodify < /tmp/<uid>-sambaNTPassword'
	echo '		oss_ldapmodify < /tmp/<uid>-sambaLMPassword'
	echo '		oss_ldapmodify < /tmp/<uid>-userPassword'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		      --uid         : User name.(type=string)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
}

if [ -z "$1" ]
then
	usage
	exit
fi

while [ "$1" != "" ]; do
    case $1 in
	-u | --uid=* )
				uid=$(echo $1 | sed -e 's/--uid=//g');
				if [ "$uid" = '' ]
				then
					usage
					exit;
				fi;;
	-d | --description )    description
				exit;;
	-h | --help )           usage
				exit;;
	* )                     usage
				exit 1
    esac
    shift
done
#echo $uid

oss_ldapsearch -LLL uid=$uid sambaNTPassword > /tmp/$uid-sambaNTPassword
sed -i 's/sambaNTPassword/replace: sambaNTPassword\nsambaNTPassword/' /tmp/$uid-sambaNTPassword
oss_ldapsearch -LLL uid=$uid sambaLMPassword > /tmp/$uid-sambaLMPassword
sed -i 's/sambaLMPassword/replace: sambaLMPassword\nsambaLMPassword/' /tmp/$uid-sambaLMPassword
oss_ldapsearch -LLL uid=$uid userPassword > /tmp/$uid-userPassword
sed -i 's/userPassword/replace: userPassword\nuserPassword/'          /tmp/$uid-userPassword
