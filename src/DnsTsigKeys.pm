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

use DnsData qw(@tsig_keys @new_includes @deleted_includes);
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
    if (defined $contents && $contents =~ /.*key[ \t]+([^ \t}{;]+).* {/)
    {
	return [$1];
    }
    return [];
}

BEGIN{$TYPEINFO{AddTSIGKey}=["function", "boolean", "string"];}
sub AddTSIGKey {
    my $self = shift;
    my $filename = shift;

    my @new_keys = @{$self->AnalyzeTSIGKeyFile ($filename) || []};
    y2milestone ("Reading TSIG file $filename");
    $filename = $self->NormalizeFilename ($filename);
    @tsig_keys = grep {
	$_->{"filename"} ne $filename;
    } @tsig_keys;
    my $contents = SCR->Read (".target.string", $filename);
    if (0 != @new_keys)
    {
	foreach my $new_key (@new_keys) {
	    y2milestone ("Having key $new_key, file $filename");
	    # remove the key if already exists
	    my @current_keys = grep {
		$_->{"key"} eq $new_key;
	    } @tsig_keys;
	    if (@current_keys > 0)
	    {
		$self->DeleteTSIGKey ($new_key);
	    }
	    #now add new one
	    my %new_include = (
		"filename" => $filename,
		"key" => $new_key,
	    );
	    push @tsig_keys, \%new_include;
	    push @new_includes, \%new_include;
	}
	return Boolean (1);
    }
    return Boolean (0);
}

BEGIN{$TYPEINFO{DeleteTSIGKey}=["function", "boolean", "string"];}
sub DeleteTSIGKey {
    my $self = shift;
    my $key = shift;
    
    y2milestone ("Removing TSIG key $key");
    #add it to deleted list
    my @current_keys = grep {
	$_->{"key"} eq $key;
    } @tsig_keys;
    if (@current_keys == 0)
    {
	y2error ("Key not found");
	return Boolean(0);
    }
    foreach my $k (@current_keys) {
	push @deleted_includes, $k;
    }
    #remove it from current list
    @new_includes = grep {
	$_->{"key"} ne $key;
    } @new_includes;
    @tsig_keys = grep {
	$_->{"key"} ne $key;
    } @tsig_keys;

    return Boolean (1);
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
