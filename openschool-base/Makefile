# Copyright (c) 2012 Peter Varkoly Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2006 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
DESTDIR         = /
SHARE           = $(DESTDIR)/usr/share/oss/
SUBDIRS		= system setup
TOPACKAGE	= Makefile PRODNAME RELEASE VERSION buildit-local docs mkspec system setup
VERSION         = $(shell test -e ../VERSION && cp ../VERSION VERSION ; cat VERSION)
RELEASE         = $(shell cat RELEASE )
NRELEASE        = $(shell echo $(RELEASE) + 1 | bc )
PRODNAME        = $(shell cat PRODNAME)
REQPACKAGES     = $(shell cat REQPACKAGES)
HERE		= $(shell pwd)
PACKAGE		=openschool-base

install:
		for i in $(REQPACKAGES); do \
		  rpm -q --quiet $$i || { echo "Missing Required Package $$i"; exit 1; } \
		done  
		for i in $(SUBDIRS); do \
		  cd $$i; \
		  make install DESTDIR=$(DESTDIR) SHARE=$(SHARE) PRODNAME=$(PRODNAME); \
		  cd .. ;\
		done  

dist:
		if [ -e $(PACKAGE) ] ;  then rm -rf $(PACKAGE) ; fi   
		mkdir $(PACKAGE)
		for i in $(TOPACKAGE); do \
		   cp -rp $$i $(PACKAGE); \
		done
		if [ -e package ]; then rm -r package; fi
		mkdir package
		find $(PACKAGE) -not -regex "^.*\.git\/.*" -xtype f > files; \
		  tar jcpf $(PACKAGE).tar.bz2 -T files; 
		rm files  
		sed 's/@VERSION@/$(VERSION)/'   $(PACKAGE).spec.in > $(PACKAGE).spec
		sed -i 's/@RELEASE@/$(NRELEASE)/' $(PACKAGE).spec
		rm -rf $(PACKAGE) 
		if [ -d /data1/OSC/home\:openschoolserver/$(PACKAGE) ] ; then \
			cd /data1/OSC/home\:openschoolserver/$(PACKAGE); osc up; cd $(HERE);\
			cp $(PACKAGE).tar.bz2 $(PACKAGE).spec /data1/OSC/home\:openschoolserver/$(PACKAGE); \
			cd /data1/OSC/home\:openschoolserver/$(PACKAGE); \
			osc vc; \
			osc ci -m "New Build Version"; \
		fi
		echo $(NRELEASE) > RELEASE

package:	dist
		rm -rf /usr/src/packages/*
		cd /usr/src/packages; mkdir -p BUILDROOT BUILD SOURCES SPECS SRPMS RPMS RPMS/athlon RPMS/amd64 RPMS/geode RPMS/i686 RPMS/pentium4 RPMS/x86_64 RPMS/ia32e RPMS/i586 RPMS/pentium3 RPMS/i386 RPMS/noarch RPMS/i486
		cp $(PACKAGE).tar.bz2 /usr/src/packages/SOURCES
		rpmbuild -ba $(PACKAGE).spec
		for i in `ls /data1/PACKAGES/rpm/noarch/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
		for i in `ls /data1/PACKAGES/src/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
		cp /usr/src/packages/SRPMS/$(PACKAGE)-*.src.rpm /data1/PACKAGES/src/
		cp /usr/src/packages/RPMS/noarch/$(PACKAGE)-*.noarch.rpm /data1/PACKAGES/rpm/noarch/
		createrepo -p /data1/PACKAGES/

backupinstall:
	for i in $(REQPACKAGES); do \
	    rpm -q --quiet $$i || { echo "Missing Required Package $$i"; exit 1; } \
	    done  
	for i in $(SUBDIRS); do \
	    cd $$i; \
	    make backupinstall DESTDIR=$(DESTDIR) SHARE=$(SHARE) PRODNAME=$(PRODNAME); \
	    cd ..;\
	done

restore:
	for i in $(SUBDIRS); do \
	    cd $$i; \
	    make restore; \
	    cd .. ;\
	done

