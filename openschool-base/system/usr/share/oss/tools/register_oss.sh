#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

if [ "$1" = "--help" -o  "$1" = "-h" ]
then
	echo 'Usage: /usr/share/oss/tools/register_oss.sh [OPTION]'
	echo 'This script does the registration for the OSS server.'
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
	echo '	register_oss.sh'
	echo 'DESCRIPTION:'
	echo '	This script does the registration for the OSS server.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	exit
fi

touch /var/adm/oss/registering
. /etc/sysconfig/schoolserver
ARCH=$( uname -m )
OSSV=$( rpm -q --qf %{VERSION} openschool-base )
#Clean up the products
for i in /etc/products.d/*
do
	[ ! -e "$i" ] && continue;
	[ $i = "/etc/products.d/sles-oss.prod" ] && continue;
	rm $i;		
	
done
#Set the products
for i in sle-sdk.prod SUSE_SLES.prod
do
	/usr/bin/wget -O /etc/products.d/$i http://repo.openschoolserver.net/products/$OSSV/$i.$ARCH
done
test -e /etc/products.d/baseproduct && rm /etc/products.d/baseproduct
ln -s /etc/products.d/SUSE_SLES.prod /etc/products.d/baseproduct
#Get the repo certificate
/usr/bin/wget -O /etc/ssl/certs/OSS_REPO_CA.pem http://repo.openschoolserver.net/OSS_REPO_CA.pem
/usr/bin/c_rehash /etc/ssl/certs/
/usr/bin/wget -O /etc/suseRegister.conf http://repo.openschoolserver.net/suseRegister.conf
/usr/bin/suse_register -f -a regcode="$SCHOOL_REG_CODE" -a hostname=$( hostname -f ) --restore-repos
zypper mr -e --all
zypper mr -r --all
REGISTERED=$( zypper ls | grep SMT-http_repo_openschoolserver_net )

if [ "$REGISTERED" ]
then
	zypper -n --gpg-auto-import-keys ref
	touch /var/adm/oss/registered
	test -e /var/adm/oss/failed-to-register && rm /var/adm/oss/failed-to-register
else
	touch /var/adm/oss/failed-to-register
fi
/etc/cron.daily/oss.list-updates
rm    /var/adm/oss/registering
