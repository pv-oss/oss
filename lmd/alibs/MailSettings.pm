# LMD  test modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ 
	push @INC,"/usr/share/oss/lib/";
	push @INC,"/usr/share/YaST2/modules/";
}

package MailSettings;

use strict;
use oss_base;
use YaPI::MailServer;
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
		"Set",
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Mail Settings' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 90 },
		 { variable     => [ "mailRelay",     [ type => "string", label=>"Mail Relay" ] ] },
		 { variable     => [ "systemMail",    [ type => "string", label=>"Send System Messages to:" ] ] },
		 { variable     => [ "newDenyClient", [ type => "string", help=>"Here you can enter mail domain or email addresses from which you do not want to get email", label=>"New Denied Sender" ] ] },
		 { variable     => [ "AccessList",    [ type => "list",   size=>10, help => 'Select Entry to delete', label=>"Denied Mail Sender:" ] ] }
	];
}

sub default
{
	my $this           = shift;
	my $GlobalSetting  = YaPI::MailServer->ReadGlobalSettings(main::GetSessionValue('userpassword'));
	my $MailPrevention = YaPI::MailServer->ReadMailPrevention(main::GetSessionValue('userpassword'));
	my @AL	= ();
	foreach my $i ( @{$MailPrevention->{AccessList}} )
	{
		push @AL, $i->{MailClient};
	}
	@AL = sort @AL;
	my $systemMail  = `grep "^root:" /etc/aliases | gawk '{print \$2}'`;
	chomp $systemMail;
	return [
		{ mailRelay     => $GlobalSetting->{SendingMail}->{RelayHost}->{Name} },
		{ User          => $GlobalSetting->{SendingMail}->{RelayHost}->{Account} },
		{ Password      => $GlobalSetting->{SendingMail}->{RelayHost}->{Password} },
		{ systemMail    => $systemMail },
		{ newDenyClient => "" },
		{ AccessList    => \@AL },
		{ action        => "Cancel" },
		{ action        => "Set" }
	];
}

sub Set
{
	my $this   = shift;
	my $reply  = shift  || return undef;

	my $GlobalSetting  = YaPI::MailServer->ReadGlobalSettings(main::GetSessionValue('userpassword'));
	my $MailPrevention = YaPI::MailServer->ReadMailPrevention(main::GetSessionValue('userpassword'));
	my @AL = ();

	# TODO check the values!
	if( $reply->{User} && $reply->{Password} )
	{
		$GlobalSetting->{SendingMail}->{RelayHost}->{Auth}    = 1;
		$GlobalSetting->{SendingMail}->{RelayHost}->{Account} = $reply->{User};
		$GlobalSetting->{SendingMail}->{RelayHost}->{Password}= $reply->{Password};
	}
	if( $reply->{mailRelay} )
	{
		$GlobalSetting->{SendingMail}->{RelayHost}->{Name} = $reply->{mailRelay};
		$GlobalSetting->{SendingMail}->{Type} = 'relayhost';
	}
	else
	{
		$GlobalSetting->{SendingMail}->{Type} = 'DNS';
	}
	$GlobalSetting->{Changed} = 1;
	YaPI::MailServer->WriteGlobalSettings($GlobalSetting, main::GetSessionValue('userpassword'));

	# Mail Prevention
	if( $reply->{newDenyClient} )
	{
		push @AL, { MailClient => $reply->{newDenyClient}, MailAction => 'REJECT ' } ;
	}
	foreach my $i ( @{$MailPrevention->{AccessList}} )
	{
		if( $i->{MailClient} ne $reply->{AccessList} )
		{
			push @AL, $i ;
		}
	}
	$MailPrevention->{AccessList} = \@AL;
	$MailPrevention->{Changed}    = 1;
	YaPI::MailServer->WriteMailPrevention($MailPrevention,main::GetSessionValue('userpassword'));

	# Save sending system mail to
	my $systemMail = $reply->{systemMail};
	$systemMail  =~ s/ //g;

	open(FILE,'/etc/aliases');
        my $aliases;
	while(<FILE>)
        {
	    if( !/^root:/ )
	    {
	        $aliases .= $_;
	    }
	}
	close(FILE);
	if( $systemMail ne '' )
	{
	   $aliases = "root: $systemMail\n".$aliases;
	}
	open(FILE,'>/etc/aliases');
	print FILE $aliases;
	close(FILE);
	system('/usr/bin/newaliases');
	system('/sbin/rcpostfix reload');

	# Mail Prevention
	default();
}

1;
