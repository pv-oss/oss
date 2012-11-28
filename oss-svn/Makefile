# Make file for the SL System Managemant Daemon
DESTDIR         = /
LMDDIR          = $(DESTDIR)/usr/share/lmd
REQPACKAGES     = $(shell cat REQPACKAGES)
VERSION         = $(shell test -e ../VERSION && cp ../VERSION VERSION ; cat VERSION)
RELEASE         = $(shell cat RELEASE)
NRELEASE        = $(shell echo $(RELEASE) + 1 | bc )
HERE		= $(shell pwd)
PACKAGE		=oss-svn

dist:
	if [ -e $(PACKAGE) ]; then rm -rf $(PACKAGE); fi
	mkdir $(PACKAGE)
	#TODO cp something
	cp Makefile setup-svn.sh $(PACKAGE)/
	rsync -aC raddb/ $(PACKAGE)/raddb/
	tar cjf $(PACKAGE).tar.bz2 $(PACKAGE)
	sed    "s/@VERSION@/$(VERSION)/" $(PACKAGE).spec.in >  $(PACKAGE).spec
	sed -i "s/@RELEASE@/$(RELEASE)/" $(PACKAGE).spec
	if [ -d /data1/OSC/home\:openschoolserver/$(PACKAGE) ] ; then \
	        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); osc up; cd $(HERE);\
	        cp $(PACKAGE).tar.bz2 $(PACKAGE).spec /data1/OSC/home\:openschoolserver/$(PACKAGE); \
	        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); \
	        osc ci -m "New Build Version"; \
	fi
	echo $(NRELEASE) > RELEASE

install:
	mkdir -p $(DESTDIR)/usr/share/oss/{plugins/add_group,plugins/del_group,plugins/modify_group,setup}
	install -m 750 setup-svn.sh    $(DESTDIR)/usr/share/oss/setup/
	install -m 750 add_group.sh    $(DESTDIR)/usr/share/oss/plugins/add_group/oss-svn.sh
	install -m 750 del_group.sh    $(DESTDIR)/usr/share/oss/plugins/del_group/oss-svn.sh
	install -m 750 modify_group.sh $(DESTDIR)/usr/share/oss/plugins/modify_group/oss-svn.sh

package: dist
	rm -rf /usr/src/packages/*
	cd /usr/src/packages; mkdir -p BUILDROOT BUILD SOURCES SPECS SRPMS RPMS RPMS/athlon RPMS/amd64 RPMS/geode RPMS/i686 RPMS/pentium4 RPMS/x86_64 RPMS/ia32e RPMS/i586 RPMS/pentium3 RPMS/i386 RPMS/noarch RPMS/i486
	cp $(PACKAGE).tar.bz2 /usr/src/packages/SOURCES
	sed -i '/BuildRequires: -brp-check-suse/d' $(PACKAGE).spec
	rpmbuild -ba $(PACKAGE).spec
	for i in `ls /data1/PACKAGES/rpm/noarch/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
	for i in `ls /data1/PACKAGES/src/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
	cp /usr/src/packages/SRPMS/$(PACKAGE)-*.src.rpm /data1/PACKAGES/src/
	cp /usr/src/packages/RPMS/noarch/$(PACKAGE)-*.noarch.rpm /data1/PACKAGES/rpm/noarch/
	createrepo -p /data1/PACKAGES/
