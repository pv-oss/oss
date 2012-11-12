# Copyright (c) 2012 Peter Varkoly Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
DESTDIR         = /
SHARE		= $(DESTDIR)/usr/share/oss/
VERSION         = $(shell  cat ../VERSION)

install:
	mkdir -p $(SHARE)/setup/ldap
	if [ -e update ]; then install -m 755 update $(SHARE)/setup; fi
	install -m 755 oss_setup.pl $(SHARE)/setup
	install -m 755 init-portal.pl $(SHARE)/setup
	install -m 755 update-* $(SHARE)/setup
	install -m 644 ldap/* $(SHARE)/setup/ldap 
	
backupinstall:
	mkdir -p $(SHARE)/setup/ldap
	if [ -e update ]; then install -b -m 755 update $(SHARE)/setup; fi
	install -b -m 755 oss_setup.pl $(SHARE)/setup
	install -b -m 755 init-portal.pl $(SHARE)/setup
	install -b -m 755 update-* $(SHARE)/setup
	install -b -m 644 ldap/* $(SHARE)/setup/ldap

restore:
	cd $(SHARE)/setup/; \
	for file in `find -type f -regex "^.*~"`; do \
	     mv $$file `echo "$$file" | sed 's/~//'`; \
	done
