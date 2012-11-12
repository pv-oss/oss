#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

usage ()
{
	echo 'Usage: /usr/share/oss/tools/turn_on_teachers_observ_home.sh [OPTION]'
	echo 'Script for turn on SCHOOL_TEACHER_OBSERV_HOME.'
	echo
	echo 'Options :'
	echo 'Mandatory parameters :'
	echo '		      --no           Turn off.'
	echo '		      --yes          Turn on.'
	echo 'Optional parameters :'
	echo '		-h,   --help         Display this help.'
	echo '		-d,   --description  Display the descriptiont.'
}

if [ "$1" = "--description" -o  "$1" = "-d" ]
then
	echo 'NAME:'
	echo '	turn_on_teachers_observ_home.sh'
	echo 'DESCRIPTION:'
	echo '	Script for turn on SCHOOL_TEACHER_OBSERV_HOME.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo '		      --no          : Turn off.(type=boolean)'
	echo '		      --yes         : Turn on.(type=boolean)'
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	exit
fi

if [ "$1" = "--no" ]
then
	ACCESS="no";
elif [ "$1" = "--yes"  ]
then
	ACCESS="yes";
else
	usage
	exit
fi

test -e /etc/sysconfig/schoolserver || { echo "This is not an OSS"; exit -1; }
. /etc/sysconfig/schoolserver
. /etc/sysconfig/ldap
ldapbase=`echo $BASE_CONFIG_DN | sed s/ou=ldapconfig,//`

if [ -z $SCHOOL_HOME_BASE ]; then
	SCHOOL_HOME_BASE="/home";
fi

echo "dn: cKey=SCHOOL_TEACHER_OBSERV_HOME,ou=sysconfig,$ldapbase
replace: cValue
cValue: $ACCESS" | oss_ldapmodify
/usr/sbin/oss_ldap_to_sysconfig.pl

if [ "$ACCESS" = "yes"  ]
then
	echo '[classes]
browseable = yes
comment = Folder to Observ the Students Home Directories
valid users = \@teachers
guest ok = no
path = /home/classes
writable = yes
' >> /etc/samba/$SCHOOL_NETBIOSNAME.in
	sed -i 's/^REM (.*classes)/\$1/' /var/lib/samba/netlogon/teachers.bat
	/usr/share/oss/tools/repair_sym_links.pl --access=$ACCESS
else
	/usr/bin/setfacl -R -b $SCHOOL_HOME_BASE/students
	rm -r /home/classes/
fi
