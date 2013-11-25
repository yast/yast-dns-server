#
# spec file for package yast2-dns-server
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-dns-server
Version:        3.1.2
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0
BuildRequires:	yast2-ldap-client perl-XML-Writer update-desktop-files yast2 yast2-testsuite yast2-perl-bindings
BuildRequires:  yast2-devtools >= 3.0.6

# requires DnsServerAPI::GetReverseIPforIPv6
BuildRequires:  yast2 >= 2.17.8
Requires:	/usr/bin/host
Requires:	perl-gettext
# Exporter Data::Dumper
Requires:	perl-base
# Time
Requires:	perl
Requires:	yast2-perl-bindings
Requires:	bind-utils
Requires:	yast2-ldap
Requires:	yast2-ldap-client
# /sbin/ip
Requires:	iproute2
# DnsServerUI::CurrentlyUsedIPs
Requires:	grep sed

# Script /sbin/netconfig 0.71.2+?
# FATE #303386: Network setup tools
Requires:	yast2-sysconfig

# DnsServerApi moved to yast2.rpm (bnc#392606)
# DnsServerAPI::GetReverseIPforIPv6
Requires:	yast2 >= 2.17.8

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - DNS Server Configuration

%description
This package contains the YaST2 component for DNS server configuration.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/dns-server
%{yast_yncludedir}/dns-server/*
%{yast_clientdir}/dns-server.rb
%{yast_clientdir}/dns-server_*.rb
%{yast_moduledir}/*
%{yast_desktopdir}/dns-server.desktop
%{yast_scrconfdir}/dns_named.scr
%{yast_scrconfdir}/dns_zone.scr
%{yast_scrconfdir}/cfg_named.scr
%{yast_scrconfdir}/named_forwarders.scr
%{yast_scrconfdir}/named_forwarders.scr
%{yast_scrconfdir}/convert_named_conf.scr
%{yast_agentdir}/ag_dns_zone
%{yast_agentdir}/ag_named_forwarders
%{yast_agentdir}/ag_convert_named_conf
%{yast_schemadir}/autoyast/rnc/dns-server.rnc
%doc %{yast_docdir}

