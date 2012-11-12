test -e /etc/sysconfig/schoolserver || exit 0
if [ "$(ldapsearch -LLLx '(&(cKey=SCHOOL_USE_SVN)(cValue=yes))' dn)" ]
then
	exit 0
fi
. /etc/sysconfig/ldap
. /etc/sysconfig/schoolserver
. /etc/sysconfig/apache2
LDAPBASE=`echo $BIND_DN | sed 's/cn=Administrator,//'`
echo "SCHOOL_USE_SVN
yes
The OSS is configured as a subversion (SVN) server
yesno
yes
Basis" | /usr/sbin/oss_base_wrapper.pl add_school_config
/usr/sbin/oss_ldap_to_sysconfig.pl

#Config apache2. We need the modules dav and dav_svn
for i in $APACHE_MODULES
do
	if [ $i = "dav" ];     then DAV=1 ; fi
	if [ $i = "dav_svn" ]; then DAV_SVN=1 ; fi
done
if [ -z "$DAV" ]
then
	APACHE_MODULES="$APACHE_MODULES dav"
fi
if [ -z "$DAV" ]
then
	APACHE_MODULES="$APACHE_MODULES dav_svn"
fi
sed -i "s/^APACHE_MODULES.*/APACHE_MODULES=\"$APACHE_MODULES\"/" /etc/sysconfig/apache2
mkdir -p /srv/svn
/etc/init.d/apache2 restart

