#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

. /etc/sysconfig/schoolserver

server_net=$( echo "$SCHOOL_SERVER_NET" | gawk -F '.' '{ print $1 "." $2 "." $3 }' );
remote_ip3=$( echo "$REMOTE_ADDR"     | gawk -F '.' '{ print $1 "." $2 "." $3 }' );
school_net=$( echo "$SCHOOL_NETWORK" | gawk -F '.' '{ print $1 "." $2 }' );
remote_ip=$( echo "$REMOTE_ADDR"     | gawk -F '.' '{ print $1 "." $2 }' );

if [ "$server_net" = "$remote_ip3" ]; then
        echo "Content-type: text/html";
        echo "Location: /ossadmin/
";
elif [ "$school_net" = "$remote_ip" ]; then
        echo "Content-type: text/html";
        echo "Location: https://admin/ossadmin/
";
else
        echo "Content-type: text/html";
        echo "Location: /ossadmin/
";
fi
