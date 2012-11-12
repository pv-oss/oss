#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
usage ()
{
	echo 'Usage: /usr/share/oss/tools/find_files_of_user.sh [OPTION]'
	echo 'Tool to find all files created by the user <uid> in the /home directory.'
        echo '(Creates a report of all files created by the user <uid> in the /home directory.'
	echo "The report will be saved in the homedirectory of [myuid] in the directory SearchUsersFiles."
	echo "If myuid is not given the enviroment variable \$USER will be used)"
        echo
        echo 'Options :'
        echo 'Mandatory parameters :'
        echo '		      --uid    User uid.(Ex: ./find_files_of_user.sh --uid=pjanos)'
        echo 'Optional parameters :'
        echo '		-h,   --help         Display this help.'
        echo '		-d,   --description  Display the descriptiont.'
	echo '		      --myuid        My uid.'

}

description ()
{
	echo 'NAME:'
	echo '	find_files_of_user.sh'
	echo 'DESCRIPTION:'
	echo '	Tool to find all files created by the user <uid> in the /home directory.'
	echo '	(Creates a report of all files created by the user <uid> in the /home directory.'
	echo "The report will be saved in the homedirectory of [myuid] in the directory SearchUsersFiles."
	echo "If myuid is not given the enviroment variable \$USER will be used.)"
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		      --uid         : User uid.(type=string)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	echo '		      --myuid       : My uid.(type=string)'
	exit
}

if [ -z "$1" ]
then
        usage
        exit
fi

. /etc/sysconfig/schoolserver
a=$USER
while [ "$1" != "" ]; do
    case $1 in
        --uid=* )
                                u=$(echo $1 | sed -e 's/--uid=//g');
                                if [ "$u" = '' ]
                                then
                                        usage
                                        exit;
                                fi;;
	--myuid=* )
				a=$(echo $1 | sed -e 's/--myuid=//g');
				if [ "$a" = '' ]
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


home=$( oss_get_home $u )
report=$( oss_get_home $a )
date=$( /usr/share/oss/tools/oss_date.sh )


get_name()
{
         NAME=$( oss_ldapsearch uid=$u cn | grep 'cn: ' | sed 's/cn: //')
        if [ -z "$NAME" ];
        then
                NAME=$( oss_ldapsearch uid=$u cn | grep 'cn:: ' | sed 's/cn:: //' | base64 -d )
        fi
}
get_name
if [ ! -d $report ]; then
	report=$SCHOOL_HOME_BASE/sysadmins/admin
fi
mkdir -p $report/SearchUsersFiles/



(
echo "================================================================"
echo "Filesystem Report for $NAME"
echo "================================================================"
echo
echo "Checking file system quota:"
NOQUOTA=$( quota $u 2> /dev/null | grep 'none' )
QUOTA=$( quota $u 2> /dev/null | grep '\*' )
if [ "$QUOTA" ]; then
    echo -n "$NAME is over quota: "
    echo $QUOTA | sed 's/\*//' | gawk '{ print "used :", $2/1024, "MB allowed: ", $3/1024, "MB"}'
elif [ "$NOQUOTA" ]; then
    echo "$NAME has no quota"
else 
    echo "$NAME is not over quota: "
    quota $u 2> /dev/null | grep /dev/ | awk '{ print "used :", $2/1024, "MB allowed: ", $3/1024, "MB"}'
fi
echo "================================================================="
echo
echo "Files of $NAME in $SCHOOL_HOME_BASE/all:"
find $SCHOOL_HOME_BASE/all      -type f -user $u -exec ls -lh {} \;
echo "================================================================="
echo
echo "Files of $NAME in $SCHOOL_HOME_BASE/groups:"
find $SCHOOL_HOME_BASE/groups   -type f -user $u -exec ls -lh {} \;
echo "================================================================="
echo
echo "Files of $NAME in $SCHOOL_HOME_BASE/software:"
find $SCHOOL_HOME_BASE/software -type f -user $u -exec ls -lh {} \;
echo "================================================================="
echo
echo "Windows Profiles of $NAME in MB:"
find $SCHOOL_HOME_BASE/profile/$u -maxdepth 1 -type d -exec du -s -BM {} \;
echo "================================================================="
echo
echo "Allocation of $NAME's home directory"
echo "1. Full size:"
du -sh $home
echo
echo "2. Allocation on the first level:"
du -sSh $home
echo
echo "3. The content $NAME's subdirectories in KB. Sorted by size:"
find $home -mindepth 1 -maxdepth 1 -type d -exec du -s {} \; | sort -nr
) > $report/SearchUsersFiles/$u-$date.txt
