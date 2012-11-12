#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

if [ "$1" = "--help" -o  "$1" = "-h" ]
then
        echo 'Usage: /usr/share/oss/tools/kill_conficker.sh [OPTION]'
        echo 'Create autorun.inf files in the home of the users with root rights to avoid configer attacts.'
        echo
        echo 'Options :'
        echo 'Mandatory parameters :'
        echo "          No need for mandatory parameters. (There's no need for parameters for running this script.)"
        echo 'Optional parameters :'
        echo '          -h,   --help         Display this help.'
        echo '          -d,   --description  Display the descriptiont.'
        exit
fi

if [ "$1" = "--description" -o  "$1" = "-d" ]
then
        echo 'NAME:'
        echo '  kill_conficker.sh'
        echo 'DESCRIPTION:'
        echo '  Create autorun.inf files in the home of the users with root rights to avoid configer attacts.'
        echo 'PARAMETERS:'
        echo '  MANDATORY:'
        echo "                              : No need for mandatory parameters. (There's no need for parameters for running this script.)"
        echo '  OPTIONAL:'
        echo '          -h,   --help        : Display this help.(type=boolean)'
        echo '          -d,   --description : Display the descriptiont.(type=boolean)'
        exit
fi

for i in $( /usr/sbin/oss_get_users )
do
	h=$( /usr/sbin/oss_get_home $i )
        if [ -e $h/autorun.inf ]
        then
                echo $h/autorun.inf
                mv $h/autorun.inf /tmp/autorun.inf.$i
        fi
	touch $h/autorun.inf
	chown root:root $h/autorun.inf
	chmod 600 $h/autorun.inf
done

for h in /home /home/* /home/groups/*
do
    if [ -e $h/autorun.inf ]
    then
        echo $h/autorun.inf
        mv $h/autorun.inf /tmp/autorun.inf.$( basename $h )
    fi
    touch $h/autorun.inf
    chown root:root $h/autorun.inf
    chmod 600 $h/autorun.inf
done

find /home/ -type d -name "RECYCLER" -exec rm -rf {} \; &> /dev/null

