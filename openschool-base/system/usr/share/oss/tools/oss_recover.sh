#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# oss_recover.sh
#
# $Id: oss_recover.sh,v 1.7 2007/07/05 13:05:36 lrupp Exp $

DEBUG="yes"
CONFIG=/etc/sysconfig/schoolserver
LOGFILE=/var/log/oss-recover.log

function usage (){
	echo 'Usage: /usr/share/oss/tools/oss_recover.sh [OPTION]'
	echo 'This is the oss backup restoration script.'
	echo 
	echo 'Options :'
	echo 'Mandatory parameters :'
	echo "		No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo 'Optional parameters :'
	echo "		-h,   --help         Display this help."
	echo '		-d,   --description  Display the descriptiont.'
	echo "		      --egroupware   Recover eGroupware database"
	echo "		      --home         Recover /home-directory"
	echo "		      --joomla       Recover Joomla database"
	echo "		      --ldap         Recover LDAP database"
	echo "		      --mail         Recover Emails"
	echo "		      --moodle       Revover Moodle data"
	echo "		      --openxchange  Recover openXchange database"
	echo "		      --proxy        Recover proxy settings"
	echo "		      --samba        Recover samba settings"
	echo "		      --ssh          Recover ssh settings"
	echo "		      --ssl          Recover ssl settings"
#	echo "		      --tfk          Recover time4kids database"
    exit $1
}

function description
{
	echo 'NAME:'
	echo '	oss_recover.sh'
	echo 'DESCRIPTION:'
	echo '	This is the oss backup restoration script.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	echo "		      --egroupware  : recover eGroupware database(type=boolean)"
        echo "		      --home        : recover /home-directory(type=boolean)"
        echo "		      --joomla      : recover Joomla database(type=boolean)"
        echo "		      --ldap        : recover LDAP database(type=boolean)"
        echo "		      --mail        : recover Emails(type=boolean)"
        echo "		      --moodle      : revover Moodle data(type=boolean)"
        echo "		      --openxchange : recover openXchange database(type=boolean)"
        echo "		      --proxy       : recover proxy settings(type=boolean)"
        echo "		      --samba       : recover samba settings(type=boolean)"
        echo "		      --ssh         : recover ssh settings(type=boolean)"
        echo "		      --ssl         : recover ssl settings(type=boolean)"
#       echo "		      --tfk         : recover time4kids database(type=boolean)"
	exit 0
}

function expand_network (){
	case $1 in
		10)
			TMP="10\.0\."
		;;
		192)
			TMP="192\.168\."
		;;
		172)
			TMP="172\.16\."
		;;
		*)
		;;
	esac
}

# the sorting is done in alphabetical order via the options (see PARAM variable below)
EGROUPWARE="no"
HOMEDIRS="no"
JOOMLA="no"
LDAP="no"
EMAIL="no"
MOODLE="no"
OPENXCHANGE="no"
PROXY="no"
SAMBA="no"
SSH="no"
SSL="no"

if [ -z $1 ]; then
	EGROUPWARE="yes"
	HOMEDIRS="yes"
	JOOMLA="yes"
	LDAP="yes"
	EMAIL="yes"
	MOODLE="yes"
	OPENXCHANGE="yes"
	PROXY="yes"	
	SAMBA="yes"
	SSH="yes"
	SSL="yes"
fi

for PARAM in $* ; do
    case $PARAM in
        -h|-H|--help)    
			usage 0
	;;
	-d|--description)
			description
	;;
	--egroupware)
		EGROUPWARE="yes"
		;;
	--home)
		HOMEDIRS="yes"
		;;
	--joomla)
		JOOMLA="yes"
		;;
	--ldap)
		LDAP="yes"
		;;
	--mail)
		EMAIL="yes"
		;;
	--moodle)
		MOODLE="yes"
		;;
	--openxchange|--openexchange)	
		OPENXCHANGE="yes"
		;;
	--proxy)
		PROXY="yes"
		;;
	--samba)
		SAMBA="yes"
		;;
	--ssh)	
		SSH="yes"
		;;
	--ssl)
		SSL="yes"
		;;
        \?)     
		echo "UNKNOWN argument \"-$OPTARG\"." >&2
		usage 1
		;;
	:)      
		echo "Option \"-$OPTARG\" needs an argument." >&2
		usage 1
		;;
        *)
		echo "Wrong arguments" >&2
		usage 1
            	;;
    esac
done

if [ ! -f $CONFIG ]; then
    echo -e "\033[0;31;1mThis script is for Open School Server only!\033[\0m"
    echo -e "\033[0;31;1m*********         exiting         *********\033[\0m"
    exit 1
fi

. ./$CONFIG

SCHOOL_BACKUP_FULL_DIR=`dirname $0`

# egroupware
if [ "$SCHOOL_USE_EGROUPWARE" = "yes" -a -e $SCHOOL_BACKUP_FULL_DIR/egroupware.gz -a "$EGROUPWARE" = "yes" ]; then
	echo "restoring eGroupware" >> $LOGFILE
	gunzip $SCHOOL_BACKUP_FULL_DIR/egroupware.gz
	mysql -f egroupware < $SCHOOL_BACKUP_FULL_DIR/egroupware  >> $LOGFILE  2>&1
	gzip $SCHOOL_BACKUP_FULL_DIR/egroupware
	MYSQL_RESTART="yes"
fi

# home
if [ -d $SCHOOL_BACKUP_FULL_DIR/home -a "$HOMEDIRS" = "yes" ]; then
  	echo "restoring /home-directories" >> $LOGFILE
	rsync -aH $SCHOOL_BACKUP_FULL_DIR/home/ /home/ >> $LOGFILE  2>&1
	if [ -e $SCHOOL_BACKUP_FULL_DIR/home_facls.gz -a "$HOMEDIRS" = "yes" ]; then
	  gunzip $SCHOOL_BACKUP_FULL_DIR/home_facls.gz
	  setfacl --restore=$SCHOOL_BACKUP_FULL_DIR/home_facls >> $LOGFILE  2>&1
	  gzip $SCHOOL_BACKUP_FULL_DIR/home_facls
	fi
	FILESERVER_RESTART="yes"
fi


# joomla
if [ "$SCHOOL_USE_JOOMLA" = "yes" -a -e $SCHOOL_BACKUP_FULL_DIR/joomla.gz -a "$JOOMLA" = "yes" ]; then
	echo "restoring Joomla" >> $LOGFILE
	gunzip $SCHOOL_BACKUP_FULL_DIR/joomla.gz
	mysql -f joomla < $SCHOOL_BACKUP_FULL_DIR/joomla >> $LOGFILE  2>&1
	gzip $SCHOOL_BACKUP_FULL_DIR/joomla
  	MYSQL_RESTART="yes"
fi

# ldap
if [ -e $SCHOOL_BACKUP_FULL_DIR/SLAPCAT.gz -a "$LDAP" = "yes" ]; then	
	echo "restoring LDAP database" >> $LOGFILE
	gunzip $SCHOOL_BACKUP_FULL_DIR/SLAPCAT.gz
	/etc/init.d/ldap stop
	tar czf /var/lib/ldap.org.tgz /var/lib/ldap/
	rm /var/lib/ldap/*
	/usr/sbin/slapadd < SLAPCAT >> $LOGFILE  2>&1
	gzip $SCHOOL_BACKUP_FULL_DIR/SLAPCAT
	LDAP_RESTART="yes"
fi

# email
if [ -d $SCHOOL_BACKUP_FULL_DIR/var/spool/imap/ -a "$EMAIL" = "yes" ]; then
	echo "restoring Email (includes settings)" >> $LOGFILE
	pushd $SCHOOL_BACKUP_FULL_DIR 1>/dev/null
	for i in var/spool/imap/ var/lib/imap/ ; do
	    echo "syncing Mail"  >> $LOGFILE  2>&1
	    if [ -d $i ]; then
		    rsync -aA $i /$i >> $LOGFILE  2>&1
	    fi
	done
	popd 1>/dev/null
	if [ -f $SCHOOL_BACKUP_FULL_DIR/etc/uucp/config ]; then
	   	rsync -aH $SCHOOL_BACKUP_FULL_DIR/etc/uucp/ /etc/uucp/ >> $LOGFILE  2>&1
		if grep -v \# $SCHOOL_BACKUP_FULL_DIR/etc/crontab | grep -q poll.tcpip ; then
			rsync -aH $SCHOOL_BACKUP_FULL_DIR/etc/crontab /etc/ >> $LOGFILE  2>&1
		fi
		if  grep -v \# $SCHOOL_BACKUP_FULL_DIR/etc/crontab | grep -q uucico ; then
			rsync -aH $SCHOOL_BACKUP_FULL_DIR/etc/crontab /etc/ >> $LOGFILE  2>&1
		fi
	fi
	if [ -d $SCHOOL_BACKUP_FULL_DIR/etc/postfix ]; then
	   	rsync -aH $SCHOOL_BACKUP_FULL_DIR/etc/postfix/ /etc/postfix/ >> $LOGFILE  2>&1
		rsync -a $SCHOOL_BACKUP_FULL_DIR/etc/aliases /etc/ >> $LOGFILE  2>&1
	fi
	EMAIL_RESTART="yes"
fi

# moodle
if [ "$SCHOOL_USE_MOODLE" = "yes" -a -e $SCHOOL_BACKUP_FULL_DIR/moodle.gz -a "$MOODLE" = "yes" ]; then
	echo "restoring Moodle data" >> $LOGFILE
	gunzip $SCHOOL_BACKUP_FULL_DIR/moodle.gz
	mysql -f moodle < $SCHOOL_BACKUP_FULL_DIR/moodle >> $LOGFILE  2>&1
	rsync -a $SCHOOL_BACKUP_FULL_DIR/etc/moodle-config.php /etc/
	if [ -d $SCHOOL_BACKUP_FULL_DIR/srv/www/moodledata ]; then
	  rsync -aH $SCHOOL_BACKUP_FULL_DIR/srv/www/moodledata /srv/www/moodledata >> $LOGFILE  2>&1
	fi
	gzip $SCHOOL_BACKUP_FULL_DIR/moodle
	MYSQL_RESTART="yes"
fi

# openxchange
if [ "$SCHOOL_USE_OX" = "yes" -a -e $SCHOOL_BACKUP_FULL_DIR/openexchange.gz -a "$OPENXCHANGE" = "yes" ]; then
	echo "restoring openXchange" >> $LOGFILE
	gunzip $SCHOOL_BACKUP_FULL_DIR/openexchange.gz
	su postgres -c "psql -d openexchange -f $SCHOOL_BACKUP_FULL_DIR/openexchange" >> $LOGFILE  2>&1
        gzip $SCHOOL_BACKUP_FULL_DIR/openexchange
	POSTGRESQL_RESTART="yes"
	rsync -aA $SCHOOL_BACKUP_FULL_DIR/srv/www/oss/openxchange/var/ /srv/www/oss/openxchange/var/
fi

# squidGuard
if [ -d $SCHOOL_BACKUP_FULL_DIR/var/lib/squidGuard/db -a "$PROXY" = "yes" ]; then
	echo "restoring Proxy settings" >> $LOGFILE
	rsync -aH $SCHOOL_BACKUP_FULL_DIR/var/lib/squidGuard/db/custom/ /var/lib/squidGuard/db/custom/ >> $LOGFILE  2>&1
	rsync -a  $SCHOOL_BACKUP_FULL_DIR/etc/squid/ /etc/squid/ >> $LOGFILE  2>&1
	SQUID_RESTART="yes"
fi

# samba
if [ -d $SCHOOL_BACKUP_FULL_DIR/var/lib/samba -a "$SAMBA" = "yes" ]; then
	echo "restoring samba settings" >> $LOGFILE
	rcsmb stop 1>/dev/null
	rcnmb stop 1>/dev/null
	if pidof smbd >/dev/null; then 
		echo "WARNING: Couldn't stop smbd!" >> $LOGFILE
		killall -9 smbd
		killall -9 nmbd
	fi
	rsync -a $SCHOOL_BACKUP_FULL_DIR/etc/samba/ /etc/samba/ >> $LOGFILE  2>&1
	rsync -a $SCHOOL_BACKUP_FULL_DIR/var/lib/samba/ /var/lib/samba/ >> $LOGFILE  2>&1
	pushd /var/lib/samba/ 1>/dev/null
	tdbbackup -v *.tdb >> $LOGFILE  2>&1
	popd 1>/dev/null
	pushd /etc/samba 1>/dev/null
	tdbbackup -v *.tdb >> $LOGFILE  2>&1
	popd 1>/dev/null
	FILESERVER_RESTART="yes"
fi

# SSH
if [ -d $SCHOOL_BACKUP_FULL_DIR/root -a "$SSH" = "yes" ]; then
	echo "restoring SSH settings" >> $LOGFILE
	tar cfz /root.org.tgz /root/
	rsync -aH $SCHOOL_BACKUP_FULL_DIR/root/.ssh/ /root/.ssh/ >> $LOGFILE  2>&1
	rsync -aH $SCHOOL_BACKUP_FULL_DIR/etc/ssh/ /etc/ssh/ >> $LOGFILE  2>&1
	SSH_RESTART="yes"
fi
#LDAP
if [ "$LDAP_RESTART" = "yes" ]; then
	setfacl -m u:ldap:r /etc/ssl/servercerts/serverkey.pem
	setfacl -m u:mail:r /etc/ssl/servercerts/serverkey.pem
	/usr/sbin/rcldap restart
	APACHE_RESTART="yes"
fi
# SSL
if [ -d etc/ssl -a "$SSL" = "yes" ]; then
	echo "restoring SSL settings" >> $LOGFILE
	tar cfz /etc/ssl.org.tgz /etc/ssl/
	rsync -aAH $SCHOOL_BACKUP_FULL_DIR/etc/ssl/ /etc/ssl/ >> $LOGFILE  2>&1
	SSL_RESTART="yes"
fi

# restart services which are updated....
if [ "$MYSQL_RESTART" = "yes" ]; then
	echo "restart mysql" >> $LOGFILE
	/usr/sbin/rcmysql restart
	APACHE_RESTART="yes"
fi
if [ "$POSTGRESQL_RESTART" = "yes" ]; then
	echo "restart openexchange" >> $LOGFILE
	/etc/init.d/openexchange restart
	/usr/sbin/rcpostgresql restart
	APACHE_RESTART="yes"
fi
if [ "$SSL_RESTART" = "yes" ]; then
	echo "restart sasl" >> $LOGFILE
	/sbin/rcsaslauthd try-restart
fi
if [ "$SSH_RESTART" = "yes" ]; then
	echo "restart sshd" >> $LOGFILE
	/usr/sbin/rcsshd restart
fi
if [ "$EMAIL_RESTART" = "yes" ]; then
	echo "restart mailsystem" >> $LOGFILE
	/sbin/rcpostfix restart
	/sbin/rccyrus restart
fi
if [ "$SQUID_RESTART" = "yes" ]; then
	echo "restart proxy" >> $LOGFILE
	/usr/sbin/rcsquid try-restart
fi
if [ "$FILESERVER" = "yes" ]; then
	echo "restart samba" >> $LOGFILE
	/usr/sbin/rcsmb stop
	/usr/sbin/rcnmb stop
	/usr/sbin/rcnmb start
	/usr/sbin/rcsmb start
	echo "restart nfs" >> $LOGFILE
	/usr/sbin/rcnfsserver try-restart
fi
if [ "$APACHE_RESTART" = "yes" ]; then
	echo "restart apache2" >> $LOGFILE
	/usr/sbin/rcapache2 restart
fi
exit
