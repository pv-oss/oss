#!/bin/bash

while read a b
do
	if [ $a = 'cn' ]
	then
		CN=$b
	fi
	if [ $a = 'svn' ]
	then
		SVN=1
	fi
done
. /etc/sysconfig/ldap
. /etc/sysconfig/schoolserver
. /etc/sysconfig/apache2
LDAPBASE=`echo $BIND_DN | sed 's/cn=Administrator,//'`

if [ -z "$CN" ]
then
	echo "Can not determine group name"
	exit 1
fi

if [ "$SVN" ]
then
	if [ -e /etc/apache2/vhosts.d/oss-ssl/svn-$CN.conf ]
	then
		exit 0
	fi
	cd /srv/svn
	svnadmin create $CN
	chown -R wwwrun:www $CN
	echo "<Location /svn/$CN>
	DAV svn
	SVNPath /srv/svn/$CN
	Options Indexes FollowSymLinks
	Order allow,deny
	Allow from all
	AuthType basic
	AuthName \"SVN Folder for the Group $CN\"
	AuthBasicProvider ldap
	AuthzLDAPAuthoritative on  
	AuthLDAPURL \"ldap://localhost/ou=people,$LDAPBASE?uid?one?(memberOf=cn=$CN,ou=group,$LDAPBASE)\"
	Require valid-user
</Location>
" > /etc/apache2/vhosts.d/oss-ssl/svn-$CN.conf
/etc/init.d/apache2 reload
else
	if [ -e /etc/apache2/vhosts.d/oss-ssl/svn-$CN.conf ]
	then
		rm /etc/apache2/vhosts.d/oss-ssl/svn-$CN.conf
		rm -r /srv/svn/$CN
		/etc/init.d/apache2 reload
	fi
fi
