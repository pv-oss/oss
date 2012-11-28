VERSION         = $(shell test -e ../VERSION  && cp ../VERSION  VERSION ; cat VERSION)
PRODNAME        = $(shell test -e ../PRODNAME && cp ../PRODNAME PRODNAME ; cat PRODNAME)
RELEASE         = $(shell cat RELEASE)
NRELEASE        = $(shell echo $(RELEASE) + 1 | bc )
HERE		= $(shell pwd)
PACKAGE		=proxy-oss
SUBDIRS		=etc usr var

dist:
		sed "s/@VERSION@/$(VERSION)/"      $(PACKAGE).spec.template > $(PACKAGE).spec
		sed -i "s/@PACKAGE@/$(PACKAGE)/"   $(PACKAGE).spec
		sed -i "s/@PRODNAME@/$(PRODNAME)/" $(PACKAGE).spec
		sed -i "s/@RELEASE@/$(RELEASE)/"   $(PACKAGE).spec
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "Read shalla list if necesary:"
		echo "   wget http://www.shallalist.de/Downloads/shallalist.tar.gz"
		echo "   tar xzf shallalist.tar.gz"
		echo "   mv shallalist.tar.gz var/lib/squidGuard/db/shallalist.tar.gz"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		if [ -e $(PACKAGE) ] ;  then rm -rf $(PACKAGE) ; fi
		mkdir $(PACKAGE)
		rsync -aC $(SUBDIRS) $(PACKAGE)
		tar jcpf $(PACKAGE).tar.bz2 $(PACKAGE)
		rm -r $(PACKAGE)
		if [ -z "$(NOOSC)" -a -d /data1/OSC/home\:openschoolserver/$(PACKAGE) ] ; then \
			cd /data1/OSC/home\:openschoolserver/$(PACKAGE); osc up; cd $(HERE);\
		        cp $(PACKAGE).spec $(PACKAGE).tar.bz2 /data1/OSC/home\:openschoolserver/$(PACKAGE); \
		        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); \
			osc addremove; \
			osc vc ; \
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
