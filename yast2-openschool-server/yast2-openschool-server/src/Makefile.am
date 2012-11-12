# Makefile.am for openschool-server/src

yncludedir = @yncludedir@/openschool-server
gpgdir     = /usr/lib/rpm/gnupg/


client_DATA =			\
	openschool-network.ycp		\
	inst_openschool-network.ycp	\
	inst_openschool-setup.ycp	\
	inst_openschool-reboot.ycp	\
	openschool-network_proposal.ycp \
	openschool-server.ycp		\
	openschool-server_auto.ycp	\
	openschool-server_proposal.ycp  \
	oss_update_ldap.ycp		\
	create_cert.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	complex.ycp

module_DATA = OpenschoolServer.ycp OpenschoolServerLDAP.pm

gpg_DATA = gpg-pubkey-1878e87f-4278b884.asc \
	   gpg-pubkey-80e5483c-4263d710.asc

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(gpg_DATA)

include $(top_srcdir)/Makefile.am.common
