#
# Makefile.am for devtools/devtools/skeletons/config/src
#

yncludedir = @yncludedir@/dns-server

YCPCFLAGS = -M . -I .

client_DATA =			\
	dns-server.ycp		\
	dns-server_auto.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	misc.ycp		\
	widgets.ycp		\
	options.ycp

desktop_DATA =			\
	dns-server.desktop

module_DATA =			\
	DnsServer.pm		\
	DnsData.pm		\
	DnsRoutines.pm		\
	DnsZones.pm		\
	DnsTsigKeys.pm		\
	DnsServerUI.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

dns-server:
	test -l dns-server || ln -s . dns-server

ycpchook = dns-server

include $(top_srcdir)/Makefile.am.common
