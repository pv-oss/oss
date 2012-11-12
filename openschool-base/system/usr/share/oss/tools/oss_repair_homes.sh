#!/bin/bash
if [ -z $1 ]
then
   echo "Usage:
   $0  role"
   exit 1
fi
role=$1
for i in $( /usr/sbin/oss_get_users $role );
do
	home=$( /usr/sbin/oss_get_home $i );
	rsync -aA /etc/skel/ $home/;
	chown -R $i:$role $home;
	mkdir -pm 700 /home/profile/$i;
	chown $i /home/profile/$i;
	echo "DONE $i:$role $home /home/profile/$i";
done
