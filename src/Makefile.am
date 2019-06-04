# Sources for dns-server

module_DATA = \
  modules/DnsServerUI.rb \
  modules/DnsFakeTabs.rb \
  modules/DnsServerHelperFunctions.rb \
  modules/DnsZones.pm \
  modules/DnsData.pm \
  modules/DnsTsigKeys.pm \
  modules/DnsServer.pm \
  modules/DnsRoutines.pm

module1dir = @moduledir@/YaPI
module1_DATA = \
  modules/YaPI/DNSD.pm

client_DATA = \
  clients/dns-server_auto.rb \
  clients/dns-server.rb

yncludedir = @yncludedir@/dns-server
ynclude_DATA = \
  include/dns-server/wizards.rb \
  include/dns-server/options.rb \
  include/dns-server/misc.rb \
  include/dns-server/dialogs.rb \
  include/dns-server/dialog-installwizard.rb \
  include/dns-server/dialog-main.rb \
  include/dns-server/dialog-masterzone.rb \
  include/dns-server/cmdline.rb \
  include/dns-server/helps.rb

ylibdir = @ylibdir@/dns-server
ylib_DATA = \
  lib/dns-server/service_widget_helpers.rb

scrconf_DATA = \
  scrconf/dns_zone.scr \
  scrconf/cfg_named.scr \
  scrconf/named_forwarders.scr \
  scrconf/convert_named_conf.scr \
  scrconf/dns_named.scr

agent_SCRIPTS = \
  servers_non_y2/ag_convert_named_conf \
  servers_non_y2/ag_dns_zone \
  servers_non_y2/ag_named_forwarders

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/dns-server.rnc

desktop_DATA = \
  desktop/org.opensuse.yast.DNSServer.desktop

symbolicdir = @icondir@/hicolor/symbolic/apps
symbolic_DATA = \
  icons/hicolor/symbolic/apps/yast-dns-server-symbolic.svg
scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-dns-server.svg

EXTRA_DIST = $(module_DATA) $(module1_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA) $(ylib_DATA) $(symbolic_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
