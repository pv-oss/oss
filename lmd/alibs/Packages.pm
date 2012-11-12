# LMD Packages modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package Packages;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use vars qw(@ISA);
@ISA = qw(oss_base);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"setRegcode",
		"set",
		"searchPackages",
		"Search",
		"showUpdates",
		"applyUpdates",
		"install",
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Package Management' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 13 },
		 { variable     => [ "filter",     [ type => "string", label=>"Search Filter for Packages" ] ] },
		 { variable     => [ "install",    [ type => "action" ] ] },
		 { variable     => [ "enabled",    [ type => "boolean" ] ] },
		 { variable     => [ "refresh",    [ type => "boolean" ] ] },
		 { variable     => [ "install",    [ type => "boolean" ] ] }
	];
}

sub default
{
	my $this  = shift;
	if( -e '/var/run/zypp.pid' )
	{
		return {
			TYPE    => 'NOTICE',
			MESSAGE => 'An other installations or update process is running. Please try it later'
		}
	}
	if ( $this->{SYSCONFIG}->{SCHOOL_REG_CODE} !~ /([0-9A-Z]{4}-[0-9A-Z]{4})-([0-9A-F]{4}-[0-9A-F]{4})-[0-9A-F]{4}/i )
	{
		return [
			{ subtitle => 'This Product is not yet Registered' },
			{ regcode  => '' },
			{ action   => 'cancel' },
			{ name     => 'action', value => 'setRegcode' , attributes => [ label => 'apply' ] }
		];
	}
	else
	{
		if( -e '/var/adm/oss/registering' )
		{
			return {
				TYPE => 'NOTICE',
				MESSAGE1 => 'Registering started.'
			};
		}
		if( ! -e '/var/adm/oss/registered' )
		{
			my $tmp = cmd_pipe('at now', '/usr/share/oss/tools/register_oss.sh');
			return {
				TYPE => 'NOTICE',
				MESSAGE1 => 'Registering started.'
			};
		}
	}

	my $repos = `LANG=en_EN zypper --no-gpg-checks --gpg-auto-import-keys lr`;

	my @repo = split("\n", $repos);
	my @split_line = split(/\|/, $repo[0]);
	my @lines       = ('repos',{ head => [ "$split_line[0]", "$split_line[1]", "$split_line[2]", "$split_line[3]", "$split_line[4]" ] } );
	foreach my $line (@repo){
		if( ($line !~ /^\#(.*)/) and ($line !~ /^\-\-(.*)/)){
			@split_line = split(/\|/, $line);
			push @lines, { line => [ $split_line[0],
						{ name    => 'number', value => $split_line[0], attributes => [ type => 'label'] },
						{ name    => 'alias', value => $split_line[1], attributes => [ type => 'label'] },
						{ name    => 'name', value => $split_line[2], attributes => [ type => 'label'] },
						{ enabled => $split_line[3] =~ /Yes/ ? 1:0 },
						{ refresh => $split_line[4] =~ /Yes/ ? 1:0 },
					]};
		}

	}

	return [
		{ label => 'Avaiable Repositories'},
		{ table => \@lines},
		{ action  => "cancel" },
		{ action  => "set" },
		{ action  => "searchPackages" },
		{ action  => "showUpdates" }
	];
}

sub set
{
	my $this   = shift;
	my $reply  = shift;
	foreach my $i ( keys %{$reply->{repos}} )
	{
		if( $reply->{repos}->{$i}->{refresh} )
		{
			system("zypper modifyrepo --refresh $i");
		}
		else
		{
			system("zypper modifyrepo --no-refresh $i");
		}
		if( $reply->{repos}->{$i}->{enabled} )
		{
			system("zypper modifyrepo --enable $i");
		}
		else
		{
			system("zypper modifyrepo --disable $i");
			system("zypper modifyrepo --no-refresh $i");
		}
	}
	system("/etc/cron.daily/oss.list-updates");
	$this->default();
}

sub setRegcode
{
	my $this   = shift;
	my $reply  = shift;
	$this->set_school_config('SCHOOL_REG_CODE',$reply->{regcode});
	system("/usr/sbin/oss_ldap_to_sysconfig.pl");
	my $tmp = cmd_pipe('at now', '/usr/share/oss/tools/register_oss.sh');

	return [
		{ NOTICE => main::__('Registration may take a few minutes, please check back later to this page.') },
	]
}

sub Search
{
	my $this   = shift;
	my $reply  = shift;
	$this->searchPackages($reply);
}

sub searchPackages
{
	my $this   = shift;
	my $reply  = shift;
	my $filter   = $reply->{filter};

	if($filter eq ''){
		return [
			{ NOTICE => 'Please enter in to the search field the package name or partial name.'},
                        { subtitle => 'Search installed Packages' },
                        { filter   => $filter },
                        { action   => "cancel" },
                        { action   => "Search" }
                ];
	}else{
		system("zypper --no-gpg-checks --gpg-auto-import-keys -n se $filter | grep $filter > /tmp/my_zypfile");
		my $packages = `cat /tmp/my_zypfile`;
	        my @package = split("\n", $packages);
	        my @split_line = split(/\|/, $package[3]);

	        my @lines       = ('repos',{ head => [ "#", "Name", 'Action'] } );
		my $counter = 0;

		for(my $i=0; $i<scalar(@package); $i++){
			$counter++;
	                @split_line = split(/\|/, $package[$i]);
			my $instlabel;

			if($split_line[0] eq 'i '){
				$instlabel = 'deinstall';
			}elsif($split_line[0] eq '  '){
				$instlabel = 'install';
			}
			$split_line[2] =~ s/\"/ /g;
	                push @lines, { line => [ $counter,
						{ name => 'number', value => $counter, attributes => [ type => 'label'] },
	                                        { name => 'name', value => $split_line[1], attributes => [ type => 'label', help => "$split_line[2] ($split_line[3])"] },
	                                        { install  => main::__($instlabel) },
						{ name => 'package_name', value => "$split_line[1]", attributes => [ type => 'hidden']},
						{ name => 'install_deintall', value => "$instlabel", attributes => [ type => 'hidden']},
					]};
	        }

		return [
			{ subtitle => 'Search installed Packages' },
			{ filter   => $filter },
			{ label => 'Found Packages'},
	                { table => \@lines},
			{ rightaction   => "cancel" },
			{ rightaction   => "Search" }
		];
	}
}

sub showUpdates
{
	my $this   = shift;
	my $reply  = shift;

	if( -e '/var/adm/oss/update-started' )
	{
		my $log    = `cat /var/adm/oss/update-started`;
		my $status = `cat $log`;
		return {
			TYPE => 'NOTICE',
			MESSAGE1 => 'Update Already Started',
			NOTRANSLATE_MESSAGE2 => $status
		};
	}
	my $updates = `cat /var/adm/OSS-Updates`;
	my @updates = split("\n", $updates);
	shift(@updates);
	shift(@updates);

	my @split_line = split(/\|/, $updates[0]);
	my @lines      = ('packages',{ head => ["$split_line[0]", "$split_line[1]", "$split_line[2]", "$split_line[3]", "$split_line[4]", "$split_line[5]","Install" ]});
	shift(@updates);
	foreach my $line (@updates){
		if( ($line !~ /^\#(.*)/) and ($line !~ /^\-\-(.*)/)){
			@split_line = split(/\|/, $line);
			push @lines, { line => [ $split_line[2],
						{ name => 's', value => $split_line[0], attributes => [ type => 'label'] },
						{ name => 'repository', value => $split_line[1], attributes => [ type => 'label'] },
						{ name => 'name', value => $split_line[2], attributes => [ type => 'label'] },
						{ name => 'current_version', value => $split_line[3], attributes => [ type => 'label'] },
						{ name => 'available_version', value => $split_line[4], attributes => [ type => 'label'] },
						{ name => 'arch', value => $split_line[5], attributes => [ type => 'label'] },
						{ install => 1 }
					]};
		}
	}

	return [
#		{ label => 'Abort/Warning Repositories'},
		{ table => \@lines},
		{ action  => "cancel" },
		{ action  => "searchPackages" },
		{ action  => "applyUpdates" }
	];


}

sub applyUpdates
{
	my $this   = shift;
	my $reply  = shift;
	if( -e '/var/adm/oss/update-started' )
	{
		my $log    = `cat /var/adm/oss/update-started`;
		my $status = `cat $log`;
		return {
			TYPE => 'NOTICE',
			MESSAGE1 => 'Update Already Started',
			NOTRANSLATE_MESSAGE2 => $status
		};
	}
	my $PACKAGES = "";
	foreach my $i ( keys %{$reply->{packages}} )
	{
		$PACKAGES .= "$i " if( $reply->{packages}->{$i}->{install} );
	}
	$PACKAGES =~ s/\s+/ /g;
        $PACKAGES = 'DATE=`/usr/share/oss/tools/oss_date.sh`
echo "/var/log/OSS-UPDATE-$DATE" > /var/adm/oss/update-started
zypper --no-gpg-checks --gpg-auto-import-keys -n up --auto-agree-with-licenses '.$PACKAGES.' &> /var/log/OSS-UPDATE-$DATE
if [ $? ]; then 
echo "You have to reboot your OSS-server!
Bitte starten Sie Ihren OSS-Server neu!" > /var/adm/oss/must-restart
fi
/etc/cron.daily/oss.list-updates
rm /var/adm/oss/update-started';
	my $tmp = write_tmp_file($PACKAGES);
	return {
		TYPE => 'NOTICE',
		MESSAGE1 => 'Update was Started',
	};

}

sub install
{
	my $this  = shift;
	my $reply = shift;
	my $install_or_remove;
	my $imes;
	my $package = $reply->{repos}->{$reply->{line}}->{package_name};

	if( $reply->{repos}->{$reply->{line}}->{install_deintall} eq 'install'){
		$install_or_remove = 'in --auto-agree-with-licenses';
		$imes = sprintf( main::__('Installation of "%s" was Started'), $package );

	}elsif( $reply->{repos}->{$reply->{line}}->{install_deintall} eq 'deinstall'){
		$install_or_remove = 'rm';
		$imes = sprintf( main::__('Deinstallation of "%s" was Started'), $package );
	}

	if( -e '/var/adm/oss/install-started' )
        {
                my $log    = `cat /var/adm/oss/install-started`;
                my $status = `cat $log`;
                return {
                        TYPE => 'NOTICE',
                        MESSAGE1 => 'An Installation allready Started',
                        NOTRANSLATE_MESSAGE2 => $status
                };
        }


        my $p = `zypper se $package | grep $package`;
        if ($p eq '') {
                return {
                        TYPE => 'ERROR',
                        NOTRANSLATE_MESSAGE1 => sprintf( main::__('Package "%s" not found'), $package )
                };
        }

        my $tmp = cmd_pipe('at now', 'touch /var/adm/oss/install-started
DATE=`/usr/share/oss/tools/oss_date.sh`
echo "/var/log/OSS-INSTALL-$DATE" > /var/adm/oss/install-started
zypper --no-gpg-checks --gpg-auto-import-keys -n '.$install_or_remove.' '.$package.'> /var/log/OSS-INSTALL-$DATE
rm /var/adm/oss/install-started');

        return {
                TYPE => 'NOTICE',
                NOTRANSLATE_MESSAGE1 => $imes,
        };
}

1;
