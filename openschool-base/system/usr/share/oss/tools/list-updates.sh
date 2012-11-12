#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
TMP=$( mktemp /tmp/UPDATESXXXXX )

usage()
{
	echo "Usage: $0 [-k] [-r reponame] [-h]

	-k	Do not list kernel updates
	-r	List only updates from given repository
	-h	Print this page
"
}

usage()
{
	echo 'Usage: /usr/share/oss/tools/archiv_user [OPTION]'
	echo 'With this script we can list the updates.'
	echo
	echo 'Options :'
	echo 'Mandatory parameters :'
	echo "		No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo 'Optional parameters :'
	echo '		-h,   --help         Display this help.'
	echo '		-d,   --description  Display the descriptiont.'
	echo '		-k                   Do not list kernel updates.'
	echo '		-r                   List only updates from given repository.(Ex: ./list-updates.sh -r=<reponam>)'
	exit
}

description ()
{
	echo 'NAME:'
	echo '	list-updates.sh'
	echo 'DESCRIPTION:'
	echo '	With this script we can list the updates.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	echo '		-k                  : Do not list kernel updates.(type=boolean)'
	echo '		-r                  : List only updates from given repository.(Ex: ./list-updates.sh -r=<reponam>)(type=string)'
	exit
}

while [ "$1" != "" ]; do
    case $1 in
	-k )			NOKERNEL=1;;
	-r=* )			repo=$(echo $1 | sed -e 's/-r=//g')
                                if [ "$repo" = '' ]
                                then
                                        usage
                                        exit
                                fi
				ZARGS="$ZARGS -r $repo";;
        -d | --description )    description
                                exit;;
        -h | --help )           usage
                                exit;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ "$ZARGS" ]; then
	zypper -n lu $ZARGS | grep "^v" | gawk -F'|' '{ print $2 }' | sed 's/ //g' > $TMP
else
	zypper -n lu $ZARGS | grep "^v" | gawk -F'|' '{ print $3 }' | sed 's/ //g' > $TMP
fi

if [ "$NOKERNEL" ]
then
	sed -i /^kernel$/d $TMP
	sed -i /^kernel-default$/d $TMP
	sed -i /^kernel-default-base$/d $TMP
        sed -i /^kernel-default-devel$/d $TMP
        sed -i /^kernel-source$/d $TMP
        sed -i /^kexec-tools$/d $TMP
fi
cat $TMP
rm $TMP
