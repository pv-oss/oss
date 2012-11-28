# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
#
DESTDIR         = /
HOMEDIRS        = all archiv software groups profile/linux

install:
	#Install some other directories
	for i in $(HOMEDIRS); \
	do \
	  install -d -m 755 $(DESTDIR)/home/$$i; \
	done;
  
	#Install the contents of the etc directory
	mkdir -p $(DESTDIR)/etc/skel/{Import,Export} 
	mkdir -p $(DESTDIR)/etc/apache2/vhosts.d/{admin,admin-ssl}
	(  cd etc ; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -d -m 755 $(DESTDIR)/etc/$$i; \
	  done; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 644 $$i $(DESTDIR)/etc/$$i; \
	  done; \
	) 
	#Install the contents of the web server
	mkdir -p -m 755 $(DESTDIR)/srv/www/
	(  cd srv/www/; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -d -m 755 $(DESTDIR)/srv/www/$$i; \
	  done; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 644 $$i $(DESTDIR)/srv/www/$$i; \
	  done; \
	) 
	chmod 0755 $(DESTDIR)/srv/www/cgi-bin/*
	chmod 0755 $(DESTDIR)/etc/cron.daily/*   
	chmod 0755 $(DESTDIR)/etc/ppp/*/*   
	chmod 0755 $(DESTDIR)/etc/init.d/*   
	#Install the contents of the var directory
	( cd var ; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -d -m 755 $(DESTDIR)/var/$$i; \
	  done; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 644 $$i $(DESTDIR)/var/$$i; \
	  done; \
	) 

	#Install the contents of the usr directory  
	cd usr; make install;

	#Setting the product name
	for i in `grep -lr '@PROD_NAME@' $(DESTDIR)/etc $(DESTDIR)/usr/sbin $(DESTDIR)/usr/share/oss $(DESTDIR)/srv/www/oss $(DESTDIR)/srv/www/admin`; \
	do \
	  perl -pi -e 's/\@PROD_NAME\@/$(PRODNAME)/g' $$i; \
	done;

backupinstall:
	#Install the contents of the etc directory
	mkdir -p $(DESTDIR)/etc/skel/{Import,Export}
	mkdir -p $(DESTDIR)/etc/apache2/vhosts.d/{admin,admin-ssl}
	(  cd etc ; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -d -m 755 $(DESTDIR)/etc/$$i; \
	  done; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 644 $$i $(DESTDIR)/etc/$$i; \
	  done; \
	)
	#Install the contents of the web server
	mkdir -p -m 755 $(DESTDIR)/srv/www/
	(  cd srv/www/; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -d -m 755 $(DESTDIR)/srv/www/$$i; \
	  done; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 644 $$i $(DESTDIR)/srv/www/$$i; \
	  done; \
	)
	chmod 0755 $(DESTDIR)/srv/www/cgi-bin/*
	chmod 0755 $(DESTDIR)/etc/cron.daily/*
	chmod 0755 $(DESTDIR)/etc/ppp/*/*
	#Install the contents of the var directory
	( cd var ; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -d -m 755 $(DESTDIR)/var/$$i; \
	  done; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 644 $$i $(DESTDIR)/var/$$i; \
	  done; \
	)
	#Install the contents of the usr directory  
	cd usr; make backupinstall;

restore:
	#Restore the contents of the etc directory
	( cd /etc; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the contents of the web server
	( cd /srv/www; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the contents of the var directory
	( cd /var ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the contents of the usr directory
	cd usr; make restore;
