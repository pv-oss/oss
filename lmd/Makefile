# Make file for the SL System Managemant Daemon
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
DESTDIR		= /
LMDDIR		= $(DESTDIR)/usr/share/lmd
TOMCATROOT 	= $(DESTDIR)/srv/tomcat6/webapps
REQPACKAGES     = $(shell cat REQPACKAGES)
VERSION		= $(shell test -e ../VERSION && cp ../VERSION VERSION ; cat VERSION)
RELEASE		= $(shell cat RELEASE)
NRELEASE	= $(shell echo $(RELEASE) + 1 | bc )
HERE		= $(shell pwd)
PACKAGE		= lmd
DATE            = $(shell date +%Y-%m-%d)

install:
	#Are all requierd packages installed?
	for i in $(REQPACKAGES); do \
                  rpm -q --quiet $$i || { echo "Missing Required Package $$i"; exit 1; } \
        done 
	#we create the neccessary directories
	mkdir -p $(LMDDIR)/{alibs,helper,sql,lang,tools}
	mkdir -p $(TOMCATROOT)
	mkdir -p $(DESTDIR)/usr/sbin/
	mkdir -p $(DESTDIR)/etc/init.d
	mkdir -p $(DESTDIR)/etc/logrotate.d
	mkdir -p $(DESTDIR)/etc/apache2/vhosts.d/admin-ssl/
	mkdir -p $(DESTDIR)/etc/apache2/vhosts.d/oss-ssl/
	mkdir -p $(DESTDIR)/var/adm/fillup-templates/
	mkdir -p $(DESTDIR)/usr/share/oss/tools
	mkdir -p $(DESTDIR)/srv/www/cgi-bin/
	install -m 644 ossadmin.war   $(TOMCATROOT)
	install -m 700 lmd.pl      $(DESTDIR)/usr/sbin/
	cp -a tools/*              $(LMDDIR)/tools/
	install -m 644 lang/*ini   $(LMDDIR)/lang
	install -m 644 alibs/*pm   $(LMDDIR)/alibs
	install -m 755 alibs/*sh   $(LMDDIR)/alibs
	install -m 644 helper/*    $(LMDDIR)/helper
	install -m 644 sql/*       $(LMDDIR)/sql
	install -m 755 rc.lmd      $(DESTDIR)/etc/init.d/lmd
	install -m 644 jk.conf     $(DESTDIR)/etc/apache2/vhosts.d/admin-ssl/
	install -m 644 jk.conf     $(DESTDIR)/etc/apache2/vhosts.d/oss-ssl/
	install -m 755 itool.pl    $(DESTDIR)/srv/www/cgi-bin/
	install -m 755 enhance_translation.pl $(DESTDIR)/usr/share/oss/tools
	if [ -e $(DESTDIR)/usr/sbin/rclmd ] ; then \
	   rm $(DESTDIR)/usr/sbin/rclmd; \
	fi
	ln -s /etc/init.d/lmd $(DESTDIR)/usr/sbin/rclmd
	install -m 644 logrotate.lmd $(DESTDIR)/etc/logrotate.d/lmd
	install -m 644 sysconfig.lmd $(DESTDIR)/var/adm/fillup-templates/

installalibs:
	install -m 644 alibs/*pm   $(LMDDIR)/alibs
	install -m 755 alibs/*sh   $(LMDDIR)/alibs

dist:
	if [ -e lmd ]; then rm -rf lmd; fi
	mkdir lmd
	cp -rp Makefile alibs enhance_translation.pl helper images itool.pl jk.conf lang lmd.pl ossadmin.war *.lmd sql tools lmd
	find lmd \( -not -regex "^.*\.git\/.*" -a -not -regex "^.*\.svn\/.*" \) -xtype f > files; \
	    tar jcpf $(PACKAGE).tar.bz2 -T files;
	rm files
	sed "s/@VERSION@/$(VERSION)/" $(PACKAGE).spec.in > $(PACKAGE).spec
	sed -i "s/@RELEASE@/$(NRELEASE)/"  $(PACKAGE).spec
	rm -rf lmd
	if [ -d /data1/OSC/home\:openschoolserver/$(PACKAGE) ] ; then \
		cd /data1/OSC/home\:openschoolserver/$(PACKAGE); osc up; cd $(HERE);\
	        cp $(PACKAGE).tar.bz2 $(PACKAGE).spec /data1/OSC/home\:openschoolserver/$(PACKAGE); \
	        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); \
		osc vc; \
	        osc ci -m "New Build Version"; \
	fi
	echo $(NRELEASE) > RELEASE

package:        dist
	rm -rf /usr/src/packages/*
	cd /usr/src/packages; mkdir -p BUILDROOT BUILD SOURCES SPECS SRPMS RPMS RPMS/athlon RPMS/amd64 RPMS/geode RPMS/i686 RPMS/pentium4 RPMS/x86_64 RPMS/ia32e RPMS/i586 RPMS/pentium3 RPMS/i386 RPMS/noarch RPMS/i486
	cp $(PACKAGE).tar.bz2 /usr/src/packages/SOURCES
	sed -i '/-brp-check-suse/d' $(PACKAGE).spec
	rpmbuild -ba $(PACKAGE).spec
	for i in `ls /data1/PACKAGES/rpm/noarch/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
	for i in `ls /data1/PACKAGES/src/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
	cp /usr/src/packages/SRPMS/$(PACKAGE)-*.src.rpm /data1/PACKAGES/src/
	cp /usr/src/packages/RPMS/noarch/$(PACKAGE)-*.noarch.rpm /data1/PACKAGES/rpm/noarch/
	createrepo -p /data1/PACKAGES/

backupinstall:
	#create backup from ldap
	rcldap stop
	slapcat > /tmp/SLAPCAT-$(DATE)
	rcldap start
	#Are all requierd packages installed?
	for i in $(REQPACKAGES); do \
                rpm -q --quiet $$i || { echo "Missing Required Package $$i"; exit 1; } \
        done 
	#we create the neccessary directories
	mkdir -p $(LMDDIR)/{alibs,helper,sql,lang,tools}
	mkdir -p $(TOMCATROOT)
	mkdir -p $(DESTDIR)/usr/sbin/
	mkdir -p $(DESTDIR)/etc/init.d
	mkdir -p $(DESTDIR)/etc/apache2/vhosts.d/admin-ssl/
	mkdir -p $(DESTDIR)/etc/apache2/vhosts.d/oss-ssl/
	mkdir -p $(DESTDIR)/var/adm/fillup-templates/
	mkdir -p $(DESTDIR)/usr/share/oss/tools
	install -b -m 644 ossadmin.war   $(TOMCATROOT)
	install -b -m 700 lmd.pl      $(DESTDIR)/usr/sbin/
	cp -b -a tools/*              $(LMDDIR)/tools/
	install -b -m 644 alibs/*pm   $(LMDDIR)/alibs
	install -b -m 755 alibs/*sh   $(LMDDIR)/alibs
	install -b -m 644 helper/*    $(LMDDIR)/helper
	install -b -m 644 sql/*       $(LMDDIR)/sql
	install -b -m 755 rc.lmd      $(DESTDIR)/etc/init.d/lmd
	install -b -m 644 jk.conf     $(DESTDIR)/etc/apache2/vhosts.d/admin-ssl/
	install -b -m 644 jk.conf     $(DESTDIR)/etc/apache2/vhosts.d/oss-ssl/
	install -b -m 755 enhance_translation.pl $(DESTDIR)/usr/share/oss/tools
	if [ -e $(DESTDIR)/usr/sbin/rclmd ] ; then \
		rm $(DESTDIR)/usr/sbin/rclmd; \
	fi
	ln -s /etc/init.d/lmd $(DESTDIR)/usr/sbin/rclmd
	install -b -m 644 sysconfig.lmd $(DESTDIR)/var/adm/fillup-templates/

restore:
	#restore backup from ldap
	rcldap stop;\
	cp /var/lib/ldap/DB_CONFIG /tmp/;\
	rm /var/lib/ldap/*;\
	cp /tmp/DB_CONFIG /var/lib/ldap/DB_CONFIG;\
	slapadd < /tmp/SLAPCAT-$(DATE);\
	rcldap start;\
	mv $(TOMCATROOT)/ossadmin.war~ $(TOMCATROOT)/ossadmin.war; \
	mv $(DESTDIR)/usr/sbin/lmd.pl~ $(DESTDIR)/usr/sbin/lmd.pl; \
	( cd $(LMDDIR)/tools ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	( cd $(LMDDIR)/alibs ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	( cd $(LMDDIR)/helper; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	( cd $(LMDDIR)/sql; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	( cd $(DESTDIR)/etc/apache2/vhosts.d/admin-ssl; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	( cd $(DESTDIR)/etc/apache2/vhosts.d/oss-ssl; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	mv $(DESTDIR)/etc/init.d/lmd~ $(DESTDIR)/etc/init.d/lmd; \
	mv $(DESTDIR)/usr/share/oss/tools/enhance_translation.pl~ $(DESTDIR)/usr/share/oss/tools/enhance_translation.pl; \
	mv $(DESTDIR)/var/adm/fillup-templates/sysconfig.lmd~ $(DESTDIR)/var/adm/fillup-templates/sysconfig.lmd

test:
	if [ -e test ] ; then \
	     cd test; \
	fi
