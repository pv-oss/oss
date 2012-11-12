# LMD AddOns modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package AddOns;

use strict;
use oss_base;
use oss_utils;
use XML::Simple;
use Encode;
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
		"install",
		"installPackages",
		"setOptionalPackages"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Addon Installer' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 15 },
		 { variable     => [ "name",        [ type => "label"] ] },
		 { variable     => [ "install",     [ type => "action", label=>"Action" ] ] },
		 { variable     => [ "Description", [ type => "label"] ] },
		 { variable     => [ "links",       [ type => "label"] ] },
		 { variable     => [ "setOptionalPackages",  [ type => "action", label=>"apply" ] ] },
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $url    = "http://repo.openschoolserver.net/addons/addons.xml";
	my $tempfile = "/tmp/addons.xml";
	my $addonsfile = "/var/adm/oss/addons.xml";
	my $newxml = new XML::Simple;
	my $actxml = new XML::Simple;
	my $lang = main::GetSessionValue('lang');
	if( -e '/var/run/zypp.pid' )
	{
		return {
			TYPE    => 'NOTICE',
			MESSAGE => 'An other installations or update process is running. Please try it later'
		}
	}
	if( ! -e '/var/adm/oss/registered' )
	{
		return {
                        TYPE    => 'NOTICE',
                        NOTRANSLATE_MESSAGE1 => main::__('Please register on the Packages page').' --> <a href="/ossadmin/?application=Packages" target="">'.main::__('Packages').'</a>',
                }
	}
	else
	{
		system("rm -f $tempfile");
		system("wget -O $tempfile $url");
		my $isnet = (-s $tempfile > 0);
		if (!$isnet) {
				return {
					TYPE    => 'ERROR',
					MESSAGE => 'You need an internet connection to retrieve the list of available AddOn Software. Please set up the internet connection and try again to open this page'
				}
		} else {
			if (! -e $addonsfile) {system("cp $tempfile $addonsfile");}
			else {
				my $newxmlData = $newxml->XMLin($tempfile);
				my $newVersion = $newxmlData->{version};
				my $actxmlData = $actxml->XMLin($addonsfile);
				my $actVersion = $actxmlData->{version};
				my $major = ((int($newVersion) - int($actVersion)) >= 1);
				if ($major) {
					return {
						TYPE    => 'ERROR',
						MESSAGE => 'The AddOn List has a newer format and can not be handled by this module. Please install the updates for the Open School Server Administration Application'
					}
				} else {
					if ($newVersion >= $actVersion) {system("cp $tempfile $addonsfile");}
				}
			}
		}
	}

	my $xml = new XML::Simple;
	my $xmlData = $xml->XMLin($addonsfile);
	my $a = $xmlData->{OSSAddOn};
	my %b = %$a;
	my @lines = ('packages');
	foreach my $p (keys %b) {
#		my $instlabel = `zypper --no-gpg-checks --gpg-auto-import-keys -n se -i $b{$p}->{Package} | grep $b{$p}->{Package}`;
#		my $instlabel = cmd_pipe("/root/Documents/test.pl","package $b{$p}->{Package}\ncmd available_installed");
		my $instlabel = `/usr/share/oss/tools/check_install_package.pl --available_installed --packages="$b{$p}->{Package}"`;

		my $longdescript = $b{$p}->{Description}[0]->{Long};
		my $d = $b{$p}->{Description};
		my @descripts = @$d;
		foreach my $desc (@descripts) {
			if (uc($desc->{lang}) eq uc($lang)) {
				if (ref($b{$p}->{Description}[1]->{Long}) eq ''){$longdescript = $b{$p}->{Description}[1]->{Long};}
			}
		}
		my $hostname = `hostname -f`;
		$hostname =~ s/\s+$//;
		$b{$p}->{OSS_URL} =~ s/\$schoolserver\$/$hostname/g;
		$longdescript = encode('UTF-8', $longdescript);
		if($instlabel eq 0){
			$instlabel = 'install';
		}else{
			$instlabel = 'deinstall';
		}
		push @lines, {line => [$b{$p}->{Package},
		{ name  => 'name', value => $b{$p}->{Description}[0]->{Short}, "attributes" => [type => "label"] },
		{ install  => main::__($instlabel)},
		{ name  => 'Description',  value => $longdescript."\n".$b{$p}->{Description}[0]->{URL}  , "attributes"  => [type => "label"]},
		{ name  => 'links',  value => $b{$p}->{OSS_URL}.'<br><a href="'.$b{$p}->{EXT_URL}.'" target="_blank">'.main::__('Documentation').'</a>' , "attributes"  => [type => "label"]}
		]};
	}

		return
			[
			{ table     =>  \@lines },
			];
}

sub setRegcode
{
	my $this   = shift;
	my $reply  = shift;
	$this->set_school_config('SCHOOL_REG_CODE',$reply->{regcode});
	$this->default();
}


sub installPackages
{
	my $this    = shift;
	my $package = shift;
	my @packs = split(' ',$package);
	my $pname = @packs[0];

	system("zypper --no-gpg-checks --gpg-auto-import-keys -n ref");

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
	my $check_install_or_uninstall = `/usr/share/oss/tools/check_install_package.pl --check_install_or_uninstall --packages="$pname"`;
#	print $check_install_or_uninstall."----->available_pck\n";

	if($check_install_or_uninstall eq 0) {
		return {
			TYPE => 'ERROR',
			NOTRANSLATE_MESSAGE1 => sprintf( main::__('Package "%s" not found'), $package )
		};
	}elsif($check_install_or_uninstall eq 'in'){
		my $tmp = cmd_pipe("at now","/usr/share/oss/tools/check_install_package.pl --in --packages='$package'");
		return {
			TYPE => 'NOTICE',
			NOTRANSLATE_MESSAGE1 => sprintf( main::__('Installation of "%s" was Started'), $package ),
		};
	}elsif($check_install_or_uninstall eq 'rm'){
		my $tmp = cmd_pipe("at now","/usr/share/oss/tools/check_install_package.pl --rm --packages='$package'");
		return {
			TYPE => 'NOTICE',
			NOTRANSLATE_MESSAGE1 => sprintf( main::__('Deinstallation of "%s" was Started'), $package ),
		};
	}
}

sub install
{
	my $this   = shift;
	my $reply  = shift;
	my $package = $reply->{line};
	my $addonsfile = "/var/adm/oss/addons.xml";
	my @optpack = '';
	my $xml = new XML::Simple;
	my $xmlData = $xml->XMLin($addonsfile);
	my $a = $xmlData->{OSSAddOn};
	my %b = %$a;
	foreach my $p (keys %b) {
		if ($b{$p}->{Package} eq $package) {
			my $op = $b{$p}->{OptionalPackages}->{Package};
			my $opp = 0;
			if (defined($op)){
				my @lines = $package;
				@optpack = @$op;
				foreach my $opp (0..@optpack-1) {
					my $instlabel = `/usr/share/oss/tools/check_install_package.pl --available_installed --packages="$optpack[$opp]->{content}"`;
					push @lines, {line => [$optpack[$opp]->{content},
					{ name  => 'name', value => $optpack[$opp]->{label}, "attributes" => [type => "label"] },
					{ name  => 'install', value => $instlabel,  "attributes" => [type => "boolean"] },
					]};
				}
				return
					[
					{ NOTICE    => sprintf( main::__('Optional packages for "%s" '), $package ) },
					{ table     =>  \@lines },
					{ action    => "cancel" },
					{ name      => 'action', value => "setOptionalPackages", attributes => [label => 'apply'] }
					];
			}
		}
	}
	$this->installPackages($package);
}


sub setOptionalPackages
{
	my $this   = shift;
	my $reply  = shift;
	my %r = %$reply;
	my $addonsfile = "/var/adm/oss/addons.xml";
	my $xml = new XML::Simple;
	my $xmlData = $xml->XMLin($addonsfile);
	my $a = $xmlData->{OSSAddOn};
	my %b = %$a;
	my $package = "";
	my $packages = "";
	foreach my $p (keys %b) {
		if (exists $r{$b{$p}->{Package}}) {
		$package = $b{$p}->{Package};
		}
	}
	$packages = $package;
	my $op = $reply->{$package};
	my %opp = %$op;
	foreach my $optpack (keys %opp) {
		if ($opp{$optpack}->{install} eq '1') {
			$packages = $packages . ' ' . $optpack;
		}
	}
	$this->installPackages($packages);
}

1;
