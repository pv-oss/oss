# LMD Firewall modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package Firewall;

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
		"restart",
		"stop",
		"inComing",
		"apply",
		"outGoing",
		"applyOutgoing",
		"insert"
	];

}

sub getCapabilities
{
	#This modul is available only on OSS which is a gateway
	my $oss = oss_base->new({ aDN => 'anon' });
	if ( $oss->get_school_config('SCHOOL_ISGATE') ne 'yes' )
	{
		$oss->destroy();
		return undef;
	}
	$oss->destroy();
	return [
		 { title        => 'Firewall Configuration' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'Security' },
		 { order        => 3 },
		 { variable     => [ "protocol",     [ type => "popup",   label=>"protocol" ] ] },
		 { variable     => [ "source",       [ type => "popup",   label=>"source" ] ] },
		 { variable     => [ "ssh",          [ type => "boolean", label=>"ssh" ] ] },
		 { variable     => [ "ssh_hoch",     [ type => "boolean", label=>"ssh-hoch" ] ] },
		 { variable     => [ "admin",        [ type => "boolean", label=>"admin" ] ] },
		 { variable     => [ "schoolserver", [ type => "boolean", label=>"schoolserver" ] ] },
		 { variable     => [ "smtp",         [ type => "boolean", label=>"smtp" ] ] } ,
		 { variable     => [ "rdesktop",     [ type => "boolean", label=>"rdesktop" ] ] } ,
		 { variable     => [ "label1",       [ type => "label",   label=>"" ] ] } ,
		 { variable     => [ "delete",       [ type => "boolean", label=>"delete" ] ] }
	];
}

sub default
{
	my $this   = shift;
	my @r		    = ();

	push @r, { rightaction   => "inComing" };
	push @r, { rightaction   => "outGoing" };
	push @r, { rightaction   => "restart" };
	push @r, { rightaction   => "stop" };
	push @r, { rightaction   => "cancel" };

	return \@r;
}

sub stop
{
	my $this   = shift;
	system("/sbin/SuSEfirewall2 stop");
	$this->default;
}

sub restart
{
	my $this   = shift;
	system("/sbin/SuSEfirewall2 start");
	$this->default;
}

sub inComing
{
	my $this   = shift;
	my $ssh             = 0;
	my $ssh_hoch        = 0;
	my $admin           = 0;
	my $schoolserver    = 0;
	my $smtp            = 0;
	my $rdesktop        = 0;
	my $other_ports     = "";
	my @r		    = ();

	my $fw = get_file('/etc/sysconfig/SuSEfirewall2');
	$fw =~ /^FW_SERVICES_EXT_TCP="(.*)"$/m;
 	foreach my $port ( split /\s+/, $1 )
 	{
 	    if ($port =~ /^ssh$|^22$/)    { $ssh    = 1; next; }
 	    if ($port =~ /^exp2$|^1022$/)    { $ssh_hoch    = 1; next; }
 	    if ($port =~ /^444$/)       { $admin  = 1; next; }
 	    if ($port =~ /^https$|^443$/) { $schoolserver= 1; next; }
 	    if ($port =~ /^smtp$|^25$/)      { $smtp    = 1; next; }
 	    if ($port =~ /^ms-wbt-server$|^3389$/)      { $rdesktop    = 1; next; }
 	    $other_ports .= $port." ";
 	}
	push @r, { ssh      => $ssh };
	push @r, { ssh_hoch => $ssh_hoch };
	push @r, { admin    => $admin };
	push @r, { schoolserver => $schoolserver };
	push @r, { smtp     => $smtp };
	push @r, { rdesktop     => $rdesktop };
	push @r, { other_ports   => $other_ports};
	push @r, { action   => "cancel" };
	push @r, { action   => "apply" };

	return \@r;
}

sub apply
{
	my $this   = shift;
	my $reply  = shift;
	my @EXT_TCP   = ();
	
	if($reply->{ssh})          { push @EXT_TCP, "ssh"; }
	if($reply->{admin})        { push @EXT_TCP, "444"; }
	if($reply->{schoolserver}) { push @EXT_TCP, "https"; }
	if($reply->{smtp})         { push @EXT_TCP, "smtp"; }
	if($reply->{ssh_hoch})     { push @EXT_TCP, "1022"; }
	if($reply->{rdesktop})     { push @EXT_TCP, "3389"; }
	my $ACCES = join(" ",@EXT_TCP)." ".$reply->{other_ports};
	$ACCES =~ s/\s+$//;

	system("perl -pi -e 's/^FW_SERVICES_EXT_TCP=.*\$/FW_SERVICES_EXT_TCP=\"$ACCES\"/' /etc/sysconfig/SuSEfirewall2");
	system("/sbin/SuSEfirewall2 start");
	$this->default;

}

sub outGoing
{
        my $this        = shift;
        my $reply       = shift;
        my $rooms       = $this->get_rooms('all');
        my $pcs         = $this->get_workstations();
        my @new         = ('new');
        my @rules       = ('rules');
        my @dns         = ();
        my %tmp         = ();
	my @WS		= ();
	my @ROOMS	= ();
	my %HWS		= ();
	my %HROOMS	= ();
        my $SchoolNet   = $this->get_school_config('SCHOOL_NETWORK').'/'.$this->get_school_config('SCHOOL_NETMASK');
        $HROOMS{$SchoolNet} = 'SCHOOL_NETWORK';
        push @ROOMS, [ $SchoolNet , 'SCHOOL_NETWORK' ];

	# Reading the ROOMS
        foreach my $dn (keys %{$rooms})
        {
                $tmp{$rooms->{$dn}->{"description"}->[0]} = $dn;
        }
        foreach my $i ( sort keys %tmp )
        {
                my $dn = $tmp{$i};
                my $desc     = $rooms->{$dn}->{"description"}->[0];
		my $network  = $rooms->{$dn}->{"dhcprange"}->[0].'/'.$rooms->{$dn}->{'dhcpnetmask'}->[0];
		push @ROOMS, [ $network , $desc ];
		$HROOMS{$network} = $desc;
	}

	# Reading the WORKSTATIONS
        foreach my $dn ( sort keys %{$pcs} )
        {
                my $desc    = $pcs->{$dn}->{"cn"}->[0];
		my $network = undef;
		foreach my $i ( @{$pcs->{$dn}->{"dhcpstatements"}} )
		{
			if( $i =~ /fixed-address (.*)/ )
			{
				$network  = $1.'/32';
				last;
			}
		}
		if( defined $network )
		{
			push @WS, [ $network , $desc ];
		}
		$HWS{$network} = $desc;
	}

	# Creating the header for the new room rule table
	push @new, { head =>  [
					{ name => 'source',      attributes => [ label => main::__('source'),      help => main::__('The source address. This may be a room or a workstation') ] },
					{ name => 'destination', attributes => [ label => main::__('destination'), help => main::__('The destination address. This may be an IP Address or DNS name from internet.') ] },
					{ name => 'protocol',    attributes => [ label => main::__('protocol'),    help => main::__('The protocol. Available valus tcp, udp, all') ] },
					{ name => 'port',        attributes => [ label => main::__('port'),        help => main::__('The destination port. Value or a range separated by :. Leaving this empty means all ports.') ] }
				]
		     };
	push @new, { line => [ 0, { label => 'New room rule' } ] };
	push @new, { line => [ 1,
			  { source => \@ROOMS },
			  { destination => '0/0' },
			  { protocol => ['tcp', 'udp', 'all', '---DEFAULTS---', 'all'] },
			  { port     => '' },
			  { action   => 'insert' }
		]
	};
	# Creating the header for the new workstation rule table
	push @new, { line => [ 2, { label => 'New host rule' } ] };
	push @new, { line => [ 3 , 
			  { source => \@WS },
			  { destination => '0/0' },
			  { protocol => ['tcp', 'udp', 'all', '---DEFAULTS---', 'all'] },
			  { port     => '' },
			  { action   => 'insert' }
		]
	};
	# Reading defined FWRules
	my $i = 0;
	push @rules, { head => [ 'source', 'destination', 'protocol', 'port', 'delete' ] }; 
	foreach my $RULE ( sort( split / / , `. /etc/sysconfig/SuSEfirewall2; echo -n \$FW_MASQ_NETS` ))
	{
		my ( $s , $d , $p , $port ) = split /,/ ,$RULE;
		my $sl = $s;
		$sl = $HROOMS{$s} if( defined $HROOMS{$s} );
		$sl = $HWS{$s}    if( defined $HWS{$s} );
		$p  = 'all' if( ! defined $p );
		push @rules, { line => [ $i , 
				{ source      => [ [ $s , $sl ], '---DEFAULTS---', $s ] },
				{ destination => $d },
				{ protocol    => ['tcp', 'udp', 'all', '---DEFAULTS---', $p ] },
				{ port	      => $port },
				{ delete      => 0 }
			]
		};
		$i++;
	}

	my   @ret = ();
	push @ret, { subtitle => 'Outgoing Rules' };
	push @ret, { label => main::__('Define new outgoing rules.') };
 	push @ret, { table => \@new }; 
	push @ret, { label => main::__('List of existing outgoing rules') };
	push @ret, { table => \@rules }; 
	push @ret, { action => 'cancel' };
	push @ret, { name =>   'action', value => 'applyOutgoing', attributes => [ label => main::__('apply') ] };
	return \@ret;
}

sub insert 
{
        my $this   = shift;
        my $reply  = shift;
	my $rules  = `. /etc/sysconfig/SuSEfirewall2; echo -n \$FW_MASQ_NETS`;
	if( ! $reply->{new}->{$reply->{line}}->{source} )
	{
		return [
			{ ERROR   => 'You have to select a source' },
			{ action  => 'cancel' },
			{ action  => 'outGoing' }
		]
	}
	$rules    .= ' '.createRule( $reply->{new}->{$reply->{line}} );
	system("sed -i 's#^FW_MASQ_NETS=.*\$#FW_MASQ_NETS=\"$rules\"#' /etc/sysconfig/SuSEfirewall2");
	system("/sbin/SuSEfirewall2 start");
	$this->outGoing;
}

sub applyOutgoing
{
        my $this   = shift;
        my $reply  = shift;
	my @rules  = '';
	foreach my $i ( keys %{$reply->{rules}} )
	{
		next if( $reply->{rules}->{$i}->{delete} );
		push @rules , createRule( $reply->{rules}->{$i} );
	}
	system("sed -i 's#^FW_MASQ_NETS=.*\$#FW_MASQ_NETS=\"".join(" ",@rules)."\"#' /etc/sysconfig/SuSEfirewall2");
	system("/sbin/SuSEfirewall2 start");
	$this->outGoing;
}

sub createRule
{
	my $rule = shift;
	my $s    = $rule->{source};
	my $d    = $rule->{destination};
	my $p    = $rule->{protocol};
	my $port = $rule->{port};
	if( $p eq 'all' )
	{
		return "$s,$d";
	}
	if( !$port )
	{
		$port = '1:65535';
	}
	return "$s,$d,$p,$port"
}
1;
