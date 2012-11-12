test -e /etc/sysconfig/schoolserver || exit 0
. /etc/sysconfig/ldap
. /etc/sysconfig/schoolserver
LDAPBASE=`echo $BIND_DN | sed 's/cn=Administrator,//'`

if [ "$(ldapsearch -LLLx '(&(cKey=SCHOOL_USE_RADIUS)(cValue=yes))' dn)" -a "$(ldapsearch -LLLx '(cn=ossradius)' dn)" ]
then
	DATE=$( /usr/share/oss/tools/oss_date.sh )
	cp /usr/share/oss/tools/oss-radius/oss_set_logon.pl /usr/share/oss/tools/oss-radius/oss_set_logon.pl-$DATE
	chmod 600 /usr/share/oss/tools/oss-radius/oss_set_logon.pl-$DATE
	PASSWORD=$( oss_ldapsearch cn=ossradius userPassword | grep userPassword | sed 's/userPassword:: //' | base64 -d )
	sed    s#PASSWORD#$PASSWORD#     /usr/share/oss/tools/oss-radius/oss_set_logon.pl.in > /usr/share/oss/tools/oss-radius/oss_set_logon.pl
	sed -i s/LDAPBASE/$LDAPBASE/     /usr/share/oss/tools/oss-radius/oss_set_logon.pl
	chgrp radiusd /usr/share/oss/tools/oss-radius/oss_set_logon.pl
	chmod 750     /usr/share/oss/tools/oss-radius/oss_set_logon.pl
	exit 0
fi

PASSWORD=$(mktemp -u XXXXXXXX)
cd /usr/share/oss/templates/oss-radius/
for i in $( find -type f )
do
	cp $i /etc/raddb/$i
done
sed -i s#SCHOOL_SERVER_NET#$SCHOOL_SERVER_NET# /etc/raddb/clients.conf
sed -i s#PASSWORD#$PASSWORD#     /etc/raddb/modules/ldap
sed -i s/LDAPBASE/$LDAPBASE/     /etc/raddb/modules/ldap
sed    s#PASSWORD#$PASSWORD#     /usr/share/oss/tools/oss-radius/oss_set_logon.pl.in > /usr/share/oss/tools/oss-radius/oss_set_logon.pl
sed -i s/LDAPBASE/$LDAPBASE/     /usr/share/oss/tools/oss-radius/oss_set_logon.pl
chgrp radiusd /usr/share/oss/tools/oss-radius/oss_set_logon.pl
chmod 750     /usr/share/oss/tools/oss-radius/oss_set_logon.pl
echo "SCHOOL_USE_RADIUS
yes
The OSS use the freeradius server
yesno
yes
Basis" | /usr/sbin/oss_base_wrapper.pl add_school_config

# Add daemon admin
echo "dn: ou=daemonadmins,$LDAPBASE
objectClass: organizationalUnit
ou: daemonadmins" | /usr/sbin/oss_ldapadd

echo "dn: cn=ossradius,ou=daemonadmins,$LDAPBASE
objectClass: top
objectClass: person
userPassword: $PASSWORD
cn: ossradius
sn: Admin User for FreeRadius Daemon" | /usr/sbin/oss_ldapadd

#Add new acls
echo "dn: olcDatabase={1}hdb,cn=config
add: olcAccess
olcAccess: {2}to attrs=configurationValue by dn.exact=\"cn=ossradius,ou=daemonadmins,$LDAPBASE\" write by * read break
olcAccess: {3}to attrs=sambaNTPassword,sambaLMPassword by dn.exact=\"cn=ossradius,ou=daemonadmins,$LDAPBASE\" read  by * auth break
" | ldapmodify -Y external -H ldapi:/// 

rcldap restart
/usr/share/oss/tools/oss-radius/close-ras.pl
/usr/sbin/oss_ldap_to_sysconfig.pl
insserv freeradius
rcfreeradius start
