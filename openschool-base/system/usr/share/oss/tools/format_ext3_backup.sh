#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# (c) 2011 EXTIS GmbH
# Revision: $Rev: 1618 $

usage ()
{
	echo 'Usage: /usr/share/oss/tools/format_ext3_backup.sh [OPTION]'
	echo 'With this script we can format an external storage device.'
	echo
	echo 'Options :'
	echo 'Mandatory parameters :'
	echo '		      --disk_path    External storage device or partition.(Ex: ./format_ext3_backup.sh --disk_path=/dev/sdc1)'
	echo 'Optional parameters :'
	echo '		-h,   --help         Display this help.'
	echo '		-d,   --description  Display the descriptiont.'
}

description ()
{
	echo 'NAME:'
	echo '	format_ext3_backup.sh'
	echo 'DESCRIPTION:'
	echo '	With this script we can format an external storage device.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo '		      --disk_path   : External storage device or partition.(Ex: ./format_ext3_backup.sh --disk_path=/dev/sdc1)(type=string)'
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	exit
}

if [ -z "$1" ]
then
	usage
	exit
fi

while [ "$1" != "" ]; do
    case $1 in
	--disk_path=* )
				disk_path=$(echo $1 | sed -e 's/--disk_path=//g');
				echo $disk_path
				if [ "$disk_path" = '' ]
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

echo $$ > /var/adm/oss/Format_ext3_Running
mkfs.ext3 "$disk_path"
rm /var/adm/oss/Format_ext3_Running
exit 
