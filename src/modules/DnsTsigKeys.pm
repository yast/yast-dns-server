#! /usr/bin/perl -w
# File:         modules/DnsTsigKeys.pm
# Package:      Configuration of DNS Server
# Summary:      Functions for TSIG keys handling
# Authors:      Jiri Srain <jsrain@suse.cz>
#
# $Id$

package DnsTsigKeys;

use strict;

use ycp;
use YaST::YCP qw(Boolean);
use Data::Dumper;
use Time::localtime;

use YaPI;
textdomain("dns-server");

our %TYPEINFO;

YaST::YCP::Import ("SCR");

use DnsData qw(@tsig_keys @new_includes_tsig @deleted_includes_tsig);
use DnsRoutines;

sub TSIGKeyName2TSIGKey {
    my $self = shift;
    my $key_name = shift;

    my $filename = "";
    foreach my $key (@tsig_keys) {
	if ($key->{"key"} eq $key_name)
	{
	    $filename = $key->{"filename"};
	}
    }
    if ($filename eq "")
    {
	y2error ("File with TSIG key not found");
	return "" ;
    }

    my $contents = SCR->Read (".target.string", $filename);
    if ($contents =~ /secret[ \t\n]+\"([^\"]+)\"/)
    {
	return $1;
    }
    y2error ("TSIG key not found in $filename");
    return "";
}

BEGIN{$TYPEINFO{ListTSIGKeys}=["function",["list",["map","string","string"]]];}
sub ListTSIGKeys {
    my $self = shift;

    return \@tsig_keys;
}

BEGIN{$TYPEINFO{GetTSIGKeys}=["function", ["map", "string", "any"]];}
sub GetTSIGKeys {
    my $self = shift;
    
    return {
	"removed_files" => \@deleted_includes_tsig,
	"new_files" => \@new_includes_tsig,
	"tsig_keys" => \@tsig_keys,
    };
}

BEGIN{$TYPEINFO{SetTSIGKeys}=["function", "void", ["map", "string", "any"]];}
sub SetTSIGKeys {
    my $self = shift;
    my $info = shift;

    @tsig_keys = @{$info->{"tsig_keys"} };
    @new_includes_tsig = @{$info->{"new_files"} };
    @deleted_includes_tsig = @{$info->{"removed_files"} };
}

# FIXME multiple keys in one file
# FIXME the same function in DHCP server component
BEGIN{$TYPEINFO{AnalyzeTSIGKeyFile}=["function",["list","string"],"string"];}
sub AnalyzeTSIGKeyFile {
    my $self = shift;

    my $filename = shift;

    y2milestone ("Reading TSIG file $filename");
    $filename = $self->NormalizeFilename ($filename);
    if (substr ($filename, 0, 1) ne "/")
    {
	$filename = "/etc/named.d/$filename";
    }
    my $contents = SCR->Read (".target.string", $filename);
    if (defined $contents && $contents =~ /.*key[ \t]+([^ \t}{;]+).* \{/)
    {
	return [$1];
    }
    return [];
}

BEGIN{$TYPEINFO{PushTSIGKey}=["function", "void", ["map", "string", "string"]];}
sub PushTSIGKey {
    my $self = shift;
    my $new_key = shift;

    push @tsig_keys, $new_key;
}

BEGIN{$TYPEINFO{InitTSIGKeys} = ["function", "void"];}
sub InitTSIGKeys {
    @tsig_keys = ();
}

1;

# EOF
