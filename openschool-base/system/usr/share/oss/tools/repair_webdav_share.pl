#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use Data::Dumper;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "help",
                        "description",
                );
sub usage
{
	print   'Usage: /usr/share/oss/tools/repair_webdav_share.pl [OPTION]'."\n".
		'Leiras ....'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	repair_webdav_share.pl'."\n".
		'DESCRIPTION:'."\n".
		'	Leiras ...'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"                                 : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $this  = oss_base->new();
#USERS
my @webdav_users;
my @role  = ();
my @group = ();
my @class = ();
my $user  = $this->search_users( '*', \@class,\@group,\@role);
foreach my $dn ( sort keys %{$user} )
{
	my $webdav_access_value = $this->get_vendor_object($dn,'EXTIS','WebDavAccess');
	if( $webdav_access_value->[0] ){
		print $this->get_attribute( $dn, 'uid' )."\n";
		my $user_homeDirectory = $this->get_attribute( $dn, 'homeDirectory' );
		system("setfacl -RPm u:wwwrun:rwx $user_homeDirectory/");
		system("setfacl -RdPm u:wwwrun:rwx $user_homeDirectory/");
	}
}

#GROUPS
my @groups;
my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
foreach my $role ( @$roles ){
	push @groups, $role->[0];
}
foreach my $classe ( @$classes ){
	push @groups, $classe->[0];
}
foreach my $workgroup ( @$workgroups ){
	push @groups, $workgroup->[0];
}
foreach my $group_dn ( @groups ){
	my $webdav_access_value = $this->get_vendor_object($group_dn,'EXTIS','WebDavAccess') ;
	if( $webdav_access_value->[0] ){
		print $this->get_attribute( $group_dn, 'cn')."\n";
		my $group_cn = $this->get_attribute( $group_dn, 'cn' );
		system("setfacl -RPm u:wwwrun:rwx /home/groups/$group_cn/");
		system("setfacl -RdPm u:wwwrun:rwx /home/groups/$group_cn/");
	}

}

