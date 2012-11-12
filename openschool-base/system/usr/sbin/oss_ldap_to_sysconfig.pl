#!/usr/bin/perl  -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;

my $entry;

my $oss = oss_base->new;
my $mesg = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG_BASE},
                          filter => "(objectClass=SchoolConfiguration)",
		         scope   => 'one'
		     );
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
my $date = "$year-$mon-$mday.$hour-$min";
system("cp /etc/sysconfig/schoolserver /var/adm/backup/schoolserver.$date");

my $sysconfig = "########################################################################
## Path:           Network/Server
## Description:    Basic Configuration of the Open School Server
########################################################################

";

my $sections = {};

foreach $entry ( $mesg->entries )
{
  my @path    = split /\//, $entry->get_value('configurationPath');
  my $sec     = $path[2];
  my $key     = $entry->get_value('configurationKey');
  my $value   = $entry->get_value('configurationValue') || '';
  my $type    = $entry->get_value('configurationValueType') || 'string';
  my $des     = $entry->get_value('description') || '';
  my $ro      = $entry->get_value('configurationValueRO')   || 'no';
  my $default = $entry->get_value('configurationDefaultValue') || '';
  my $values  = join ',',$entry->get_value('configurationAvailableValue') || '';
  if ( $values ne '' )
  {
    $values = '('.$values.')';
  }
  my $config  = "";
  if ( $ro eq "yes" )
  {
    $config  = "## Type:	$type".$values." readonly
## Default:	$default
";
  }
  else
  {
    $config  = "## Type:	$type".$values."
## Default:	$default
";
  }
  if( defined $des )
  {
    $config .= "# $des\n";
  }  
  $config .= "$key=\"$value\"\n";

  $sections->{$sec}->{$key} = $config;

}

foreach my $sec (sort keys %$sections)
{
  $sysconfig .= "########################################################################
## Path:        Network/Server/$sec
## Description: Configuration of the Open School Server: $sec
########################################################################

";

  foreach my $key (sort(keys %{$sections->{$sec}}))
  {
    $sysconfig .=  $sections->{$sec}->{$key}."\n";   
  }
}

write_file('/etc/sysconfig/schoolserver',$sysconfig);
