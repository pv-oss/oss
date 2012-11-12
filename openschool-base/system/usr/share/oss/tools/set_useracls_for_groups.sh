#!/bin/bash

for i in $( oss_get_users teachers );
do
    for j in $( id -Gn $i );
    do
	test -d /home/groups/$j || continue;
        setfacl -R -m u:$i:rwx /home/groups/$j;
        setfacl -R -d -m u:$i:rwx /home/groups/$j;
    done;
    echo "$i done";
done

