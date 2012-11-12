#!/bin/bash

while read a b
do
	if [ $a = 'cn' ]
	then
		CN=$b
	fi
done

if [ -z "$CN" ]
then
	echo "Can not determine group name"
	exit 1
fi

if [ -e /etc/apache2/vhosts.d/oss-ssl/svn-$CN.conf ]
then
	rm /etc/apache2/vhosts.d/oss-ssl/svn-$CN.conf
	rm -r /srv/svn/$CN
	/etc/init.d/apache2 reload
fi
