#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

for i in $( /usr/sbin/oss_get_users )
do
    h=$( /usr/sbin/oss_get_home $i )
    touch $h/autorun.inf
    chown root:root $h/autorun.inf
    chmod 600 $h/autorun.inf
    echo $i
done
touch /home/all/autorun.inf
chown root:root /home/all/autorun.inf
chmod 600 /home/all/autorun.inf

