DESTDIR         = /
LMDDIR          = $(DESTDIR)/usr/share/lmd
VERSION         = $(shell test -e ../VERSION && cp ../VERSION VERSION ; cat VERSION)
RELEASE         = $(shell cat RELEASE)
NRELEASE        = $(shell echo $(RELEASE) + 1 | bc )
HERE		= $(shell pwd)
PACKAGE         =oss-evaluate-squidlogs

install:
	mkdir -p $(LMDDIR)/{alibs,lang}
	mkdir -p $(DESTDIR)/usr/sbin/
	mkdir -p $(DESTDIR)/usr/share/oss/tools 
	install -m 755 make_squid_log_tmp.pl $(DESTDIR)/usr/share/oss/tools/
	install -m 750 oss_evaluate_squid_logs.pl $(DESTDIR)/usr/sbin/
	install -m 644 OSSEvaluateSquidlogs.pm $(LMDDIR)/alibs
	install -m 644 DE_OSSEvaluateSquidlogs.ini $(LMDDIR)/lang/

dist:
	if [ -e $(PACKAGE) ]; then rm -rf $(PACKAGE); fi
	mkdir $(PACKAGE)
	cp Makefile *.pm *.pl *.ini $(PACKAGE)
	tar jcpf $(PACKAGE).tar.bz2  $(PACKAGE)
	sed "s/@VERSION@/$(VERSION)/" $(PACKAGE).spec.in > $(PACKAGE).spec
	sed -i "s/@RELEASE@/$(NRELEASE)/"  $(PACKAGE).spec
	rm -rf $(PACKAGE)
	if [ -d /data1/OSC/home\:openschoolserver/$(PACKAGE) ] ; then \
	        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); osc up; cd $(HERE);\
	        cp $(PACKAGE).tar.bz2 $(PACKAGE).spec /data1/OSC/home\:openschoolserver/$(PACKAGE); \
	        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); \
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
