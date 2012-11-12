#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

arg=$1

if [ "$arg" = "--help" -o  "$arg" = "-h" ]
then
	echo 'Usage: /usr/share/oss/tools/reset_home.sh [OPTION]'
	echo 'Resets directories in /home.'
	echo
	echo 'Options :'
	echo 'Mandatory parameters :'
	echo "		No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo 'Optional parameters :'
	echo '		-h,   --help         Display this help.'
	echo '		-d,   --description  Display the descriptiont.'
	echo '		-a,   --all          Resets all directories in /home recursively including profiles and home directories of the users.'
	exit
fi

if [ "$arg" = "--description" -o  "$arg" = "-d" ]
then
	echo 'NAME:'
	echo '	reset_home.sh'
	echo 'DESCRIPTION:'
	echo '	Resets directories in /home.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	echo '		-a,   --all         : Resets all directories in /home recursively including profiles and home directories of the users.(type=boolean)'
	exit
fi

. /etc/sysconfig/schoolserver

/bin/chown root /home/*

/bin/mkdir -p  /home/groups
/bin/chmod 755 /home/groups
/bin/mkdir -p  /home/profile
/bin/chmod 755 /home/profile
/bin/mkdir -p  /home/templates
/bin/chmod 750 /home/templates
/bin/mkdir -p  /home/all
if [ $SCHOOL_TYPE = "primary" ]
then
        /bin/chmod    1777   /home/all
else
        /bin/chmod    1770   /home/all
fi
/bin/mkdir -p   /home/software
/bin/chmod 1775 /home/software
/bin/mkdir -p   /home/students
/bin/chmod 751  /home/students
/bin/mkdir -p   /home/teachers
/bin/chmod 751  /home/teachers
/bin/mkdir -p   /home/administration
/bin/chmod 750  /home/workstations

/bin/chgrp 	 templates /home/templates
/usr/bin/setfacl -b                      /home/all
/usr/bin/setfacl -m m::rwx               /home/all
/usr/bin/setfacl -m g:teachers:rwx       /home/all
/usr/bin/setfacl -m g:students:rwx       /home/all
/usr/bin/setfacl -m g:administration:rwx /home/all
/bin/chgrp teachers                      /home/software
/usr/bin/setfacl -b                      /home/software
/usr/bin/setfacl -m g:students:rx        /home/software
/usr/bin/setfacl -m g:administration:rx  /home/software
/bin/chgrp          students             /home/students
/bin/chgrp          teachers             /home/teachers
/bin/chgrp          administration       /home/administration
/bin/chgrp          workstations         /home/workstations
/usr/bin/setfacl -b                      /home/workstations
/usr/bin/setfacl -m g:teachers:rx        /home/workstations

if test -d /home/groups/STUDENTS
then
	/usr/bin/setfacl -b                     /home/groups/STUDENTS
	/usr/bin/setfacl -m g:teachers:rx       /home/groups/STUDENTS
	/usr/bin/setfacl -d -m g:teachers:rx    /home/groups/STUDENTS
fi

if [ $SCHOOL_TEACHER_OBSERV_HOME = "yes" ]
then
	/bin/mkdir -p       /home/classes
	/bin/chmod 750      /home/classes
	/bin/chgrp teachers /home/classes
fi

if [ "$arg" = "-a" -o  "$arg" = "--all" ]
then
	for cn in $(ldapsearch -x objectclass=schoolGroup cn | grep cn: | sed 's/cn: //')
	do
	    i=/home/groups/$cn
	    /bin/mkdir -p  $i
	    gid=`/usr/sbin/oss_get_gid $cn`
	    if [ "$gid" ] 
	    then
		/bin/chmod -R 2771 $i
		chgrp -R $gid  $i
		/usr/bin/setfacl -b $i
		/usr/bin/setfacl -d -m g::rwx $i
		/usr/bin/setfacl -P -R -m g::rwx $i
		echo "Repairing $i"
	    else
	    	echo "Group $cn do not exists. Can not repair $i"
	    fi
	done

	for uid in $(ldapsearch -x objectclass=schoolAccount uid | grep uid: | sed 's/uid: //')
	do
	    i=/home/profile/$uid
	    /bin/mkdir -p  $i
	    /bin/chmod -R 700 $i
	    /bin/chown -R $uid  $i
	    /usr/bin/setfacl -P -R -b $i
	    /usr/bin/setfacl -d -m u::rwx $i
	    /usr/bin/setfacl -P -R -m u::rwx $i
	    echo "Repairing $i"
	done

	for uid in $(ldapsearch -x '(&(objectclass=schoolAccount)(role=teachers))' uid | grep uid: | sed 's/uid: //')
	do
	    i=$( /usr/sbin/oss_get_home $uid)
	    /bin/mkdir -p  $i
	    /bin/chmod -R 711 $i
	    /bin/chown -R $uid  $i
	    echo "Repairing $i"
	done

	for uid in $(ldapsearch -x '(&(objectclass=schoolAccount)(role=workstations))' uid | grep uid: | sed 's/uid: //')
	do
	    i=$( /usr/sbin/oss_get_home $uid)
	    /bin/mkdir -p  $i
	    /bin/chmod -R 711 $i
	    /bin/chown -R $uid  $i
	    /bin/chgrp -R teachers $i
	    echo "Repairing $i"
	done

	for uid in $(ldapsearch -x '(&(objectclass=schoolAccount)(role=students))' uid | grep uid: | sed 's/uid: //')
	do
	    i=$( /usr/sbin/oss_get_home $uid)
	    /bin/mkdir -p  $i
	    /bin/chmod -R 711 $i
	    /bin/chown -R $uid  $i
	    mkdir -p $i/public_html; chmod 755 $i/public_html; chown $uid $i/public_html;
	    echo "Repairing $i"
	done

	if [ $SCHOOL_TEACHER_OBSERV_HOME = "yes" ]
	then
	    /usr/share/oss/tools/repair_sym_links.pl --access=yes
	fi
fi
