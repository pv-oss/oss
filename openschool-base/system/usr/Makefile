# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
DESTDIR         = /
SBINDIR		= $(DESTDIR)/usr/sbin
SHARE		= $(DESTDIR)/usr/share/oss/
PLUGINS		= add_group add_room add_school add_user \
		  del_group del_room del_school del_user \
		  modify_group modify_school modify_user


install:
	mkdir -p $(SBINDIR)
	mkdir -p $(DESTDIR)/usr/share/cups/drivers/x64

	#Install the executables	
	( cd sbin; \
	  for i in oss_* ; do \
	     install -m 755 $$i $(SBINDIR); \
	  done; \
	)

	#Install the contents of the share directory
	( cd share/oss ; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -d -m 755 $(SHARE)/$$i; \
	  done; \
	)
	#Install the contents of the tools directory
	( cd share/oss/tools ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 755 $$i $(SHARE)/tools/$$i; \
	  done; \
	)
	#Install the contents of the share directory
	( cd share/oss/lib ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 644 $$i $(SHARE)/lib/$$i; \
	  done; \
	)
	#Install the contents of the templates directory
	( cd share/oss/templates ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 644 $$i $(SHARE)/templates/$$i; \
	  done; \
	)
	#Install the contents of the plugins directory
	( cd share/oss/plugins ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 755 $$i $(SHARE)/plugins/$$i; \
	  done; \
	)
	#Install the content of the software directory
	( cd share/oss/software ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 755 $$i $(SHARE)/software/$$i; \
	  done; \
	)
	#Install the content of the cups drivers directory
	( cd share/cups/drivers ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -m 644 $$i $(DESTDIR)/usr/share/cups/drivers/$$i; \
	  done; \
	)

backupinstall:
	mkdir -p $(SBINDIR)
	mkdir -p $(DESTDIR)/usr/share/cups/drivers/x64
	#Install the executables        
	( cd sbin; \
	  for i in oss_* ; do \
	     install -b -m 755 $$i $(SBINDIR); \
	  done; \
	)
	#Install the contents of the share directory
	( cd share/oss ; \
	  for i in `find -type d -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -d -m 755 $(SHARE)/$$i; \
	  done; \
	)
	#Install the contents of the tools directory
	( cd share/oss/tools ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 755 $$i $(SHARE)/tools/$$i; \
	  done; \
	)
	#Install the contents of the share directory
	( cd share/oss/lib ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 644 $$i $(SHARE)/lib/$$i; \
	  done; \
	)
	#Install the contents of the templates directory
	( cd share/oss/templates ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 644 $$i $(SHARE)/templates/$$i; \
	  done; \
	)
	#Install the contents of the plugins directory
	( cd share/oss/plugins ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 755 $$i $(SHARE)/plugins/$$i; \
	  done; \
	)
	#Install the content of the software directory
	( cd share/oss/software ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 755 $$i $(SHARE)/software/$$i; \
	  done; \
	)
	#Install the content of the cups drivers directory
	( cd share/cups/drivers ; \
	  for i in `find -type f -not -regex "^.*\.git.*" -not -regex "^.*\.svn.*"`; do \
	    install -b -m 644 $$i $(DESTDIR)/usr/share/cups/drivers/$$i; \
	  done; \
	)

restore:
	#Restore the executables        
	( cd sbin; \
	  for i in oss_* ; do \
	     mv $(SBINDIR)/$$i~ $(SBINDIR)/$$i; \
	  done; \
	)
	#Restore the contents of the tools directory
	( cd /usr/share/oss/tools; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the contents of the share directory
	( cd /usr/share/oss/lib ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the contents of the templates directory
	( cd /usr/share/oss/templates ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the contents of the plugins directory
	( cd /usr/share/oss/plugins ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the content of the software directory
	( cd /usr/share/oss/software ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
	#Restore the content of the cups drivers directory
	( cd /usr/share/cups/drivers ; \
	  for file in `find -type f -regex "^.*~"`; do \
	    mv $$file `echo "$$file" | sed 's/~//'`; \
	  done; \
	)
