test -e /etc/sysconfig/schoolserver || exit 0
if [ "$(ldapsearch -LLLx '(&(cKey=SCHOOL_USE_RADIUS)(cValue=yes))' dn)" ]
then
	exit 0
fi
. /etc/sysconfig/ldap
. /etc/sysconfig/schoolserver
PASSWD=`/usr/sbin/oss_get_admin_pw`
LDAPBASE=`echo $BIND_DN | sed 's/cn=Administrator,//'`
for i in `find /etc/raddb -name "*.in"`
do
	mv $i ${i/.in/}
done
sed -i s#SCHOOL_SERVER_NET#$SCHOOL_SERVER_NET# /etc/raddb/clients.conf
sed -i s#PASSWD#$PASSWD# /etc/raddb/modules/ldap
sed -i s/LDAPBASE/$LDAPBASE/ /etc/raddb/modules/ldap
echo "SCHOOL_USE_RADIUS
yes
The OSS use the freeradius server
yesno
yes
Basis" | /usr/sbin/oss_base_wrapper.pl add_school_config
/usr/sbin/oss_ldap_to_sysconfig.pl
insserv freeradius
