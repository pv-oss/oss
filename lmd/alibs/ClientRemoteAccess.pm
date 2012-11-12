# LMD Firewall modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ClientRemoteAccess;

use strict;
use oss_base;
use oss_utils;
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
		"add",
		"apply"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Client Remote Access Configuration' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'Network' },
		 { order        => 30 },
		 { variable     => [ "add",         [ type => "action", label => "" ] ] },
		 { variable     => [ "ws",          [ type => "string", label => "workstation" ] ] },
		 { variable     => [ "workstation", [ type => "popup" ] ] },
		 { variable     => [ "activ",       [ type => "boolean" ] ] },
		 { variable     => [ "delete",      [ type => "boolean" ] ] }
	];
}

sub default
{
	my $other_ports     = "";

	my @newaccess = ( 'newaccess' );
	my @oldaccess = ( 'oldaccess' );
	my %ws        = ();
	my @lws       = ();
	foreach( split /\n/, `oss_get_workstations.sh` )
	{
		my ($a,$b) = split / /,$_;
		$ws{$b}    = $a;
		push @lws , [ $b, $a ];
	}
	if( ! scalar @lws )
	{
		return {
			TYPE => 'NOTICE',
			MESSAGE => 'There are no workstations registered'
		}
	};
	my $in = 0;
	foreach( split /\n/, get_file('/etc/rinetd.conf'))
	{
		if( $in )
		{
			if( /^#(\S+) (\S+) (\S+) (\S+)/ )
			{
				push @oldaccess, { line => [ "$3-$4", { extport => $2 } , { ws => $ws{$3} } , { port => $4 }, { activ => 0 }, { delete => 0 } ] };
			}
			elsif( /(\S+) (\S+) (\S+) (\S+)/ )
			{
				push @oldaccess, { line => [ "$3-$4", { extport => $2 } , { ws => $ws{$3} } , { port => $4 }, { activ => 1 }, { delete => 0 } ] };
			}
		}
		else
		{
			$in = 1 if( /^###ClientRemoteAccess###/ );
		}
	}
	push @newaccess, { line => [ '1', { extport => '' } , { workstation => \@lws } , { port => '' }, { add => main::__('add') } ] };
	
	return [
		{ table    => \@newaccess },
		{ label	   => 'Configured Client Remote Control Accesses' },
		{ table    => \@oldaccess },
		{ action   => "cancel" },
		{ action   => "apply" }
	];
}

sub apply
{
	my $this   = shift;
	my $reply  = shift;
	my @RIP    = (); #rinetd ports
	my @CP     = (); #rinetd ports to close
	my @OP     = (); #rinetd ports to open
	my @FWP    = (); #firewall ports

	my $fw = get_file('/etc/sysconfig/SuSEfirewall2');
	$fw =~ /^FW_SERVICES_EXT_TCP="(.*)"$/m;
 	foreach ( split /\s+/, $1 )
 	{
		if( /ssh|22|444|https|443|smtp/ )
		{
			push @FWP, $_;
		}
		else
		{
			push @RIP, $_;
		}
 	}
	

	# create new rinetd configuration
	my $in = 0;
	my $ri = '';
	foreach( split /\n/, get_file('/etc/rinetd.conf'))
	{
		if( $in )
		{
			if( /#(\S+) (\S+) (\S+) (\S+)/ )
			{
				if ( $reply->{oldaccess}->{"$3-$4"}->{delete} )
				{
					push @CP , $2;
					next;
				}
				if ( $reply->{oldaccess}->{"$3-$4"}->{activ} )
				{
					s/^#//;
					push @OP, $2;
				}
			}
			elsif( /^(\S+) (\S+) (\S+) (\S+)/ )
			{
				if ( $reply->{oldaccess}->{"$3-$4"}->{delete} )
				{
					push @CP , $2;
					next;
				}
				if ( !$reply->{oldaccess}->{"$3-$4"}->{activ} )
				{
					$_ = '#'.$_;
					push @CP , $2;
				}
			}
		}
		else
		{
			$in = 1 if( /^###ClientRemoteAccess###/ );
		}
		$ri .= "$_\n";
	}
	print $ri."\n";
	#remove the ports
	foreach(@RIP)
	{
		push @FWP, $_ if( ! contains($_,\@CP ) );
	}
	foreach(@OP)
	{
		push @FWP, $_ if( ! contains($_,\@FWP ) );
	}
	my $ACCES = join " ", @FWP;
	system("perl -pi -e 's/^FW_SERVICES_EXT_TCP=.*\$/FW_SERVICES_EXT_TCP=\"$ACCES\"/' /etc/sysconfig/SuSEfirewall2");
	system("/sbin/SuSEfirewall2 start");
	write_file('/etc/rinetd.conf',$ri);
	$this->rc('rinetd','reload');
	$this->default;
}

sub add
{
	my $this   = shift;
	my $reply  = shift;
	my $line   = $this->get_school_config('SCHOOL_SERVER_EXT_IP')." ".$reply->{newaccess}->{1}->{extport}.
								      " ".$reply->{newaccess}->{1}->{workstation}.
								      " ".$reply->{newaccess}->{1}->{port}."\n";
	my $fw     = get_file('/etc/sysconfig/SuSEfirewall2');
	my $ri     = get_file('/etc/rinetd.conf');
	my @ports  = split /\n/, `awk '{ print \$2 }' /etc/rinetd.conf`;

	if( $reply->{newaccess}->{1}->{extport} !~ /^\d+$/ || $reply->{newaccess}->{1}->{port} !~ /^\d+$/ )
	{
		return {
			TYPE => 'ERROR',
			CODE => 'INVALID_PORT',
			MESSAGE => 'You have to define a numeric external and a numeric internal port.'
		};
	}
	#ext port must be uniqe
	if( contains( $reply->{newaccess}->{1}->{extport}, \@ports ) )
	{
		return {
			TYPE => 'ERROR',
			CODE => 'PORT_USED_MORE_TIMES',
			MESSAGE => 'External prots must not be used more times.'
		};
	}

	$fw =~ /^FW_SERVICES_EXT_TCP="(.*)"$/m;
	$fw = $1." ".$reply->{newaccess}->{1}->{extport};
	system("perl -pi -e 's/^FW_SERVICES_EXT_TCP=.*\$/FW_SERVICES_EXT_TCP=\"$fw\"/' /etc/sysconfig/SuSEfirewall2");
	system("/sbin/SuSEfirewall2 start");

	if( $ri =~ /^###ClientRemoteAccess###/m )
	{
		$ri .= $line;
	}
	else
	{
		$ri .= "###ClientRemoteAccess###\n$line";
	}
	write_file('/etc/rinetd.conf',$ri);
	$this->rc('rinetd','reload');
	$this->default;
}

1;
