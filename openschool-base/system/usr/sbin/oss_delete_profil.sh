#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
#
# Script to copy a profil for a user
#
# Copyright (c) 2009 Peter Varkoly (peter@varkoly.de
#
. /etc/sysconfig/schoolserver

usage()
{
echo "

Usage: oss_copy_profil.sh uid OS
	uid	UID of the user
	OS	The target operating system WinNT Win2K WinXP Win3K Linux

Examples:

	oss_delete_profil.sh bigboss WinXP

	oss_delete_profil.sh minibos WinXP

"
}
if [ $# -ne 2 ]
then
  usage
  exit 1;
fi

if [ $2 = 'Linux' ]
then
	echo "Can not delete Linux profil"
else
	PROFIL=$SCHOOL_HOME_BASE'/profile/'$1'/'$2
	echo $PROFIL
	test -e $PROFIL && rm -rf $PROFIL 
	mkdir -m 700 $PROFIL
	chown $1 $PROFIL
fi
