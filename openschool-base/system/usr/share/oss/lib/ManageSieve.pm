#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
# Copyright (c) 2002 SuSE Linux AG Nuernberg, Germany.  All rights reserved.
#
#
# $Id: ManageSieve.pm,v 1.1 2006/08/11 11:02:49 pv Exp $
#
package ManageSieve;

use strict;
use IO::Socket::INET;
use IO::File;
use IO::Select;
use MIME::Base64;

sub new {
    my ($this, $host, $port) = @_;
    my $class = ref($this) || $this;
    my $self = {};
    $self->{'hostname'} = $host;
    $self->{'port'} = $port;
    $self->{'socket'} = undef; 
    $self->{'timeout'} = 100;
    $self->{'connected'} = 0;
    $self->{'authenticated'} = 0;
    bless $self, $class;
    return $self;
}

sub connect{
    my $this = shift;
    
    if( $this->{'connected'} ){
	return ("ERR", "already connected");
    }
    
    $this->{'socket'} = IO::Socket::INET->new(
			    PeerHost => $this->{'hostname'},
			    PeerPort => $this->{'port'},
			    Proto    => 'tcp',
			    Timeout  => $this->{'timeout'}
			);
    if( ! $this->{'socket'} ){
	return ("ERR", $!);
    }
    my $socket = $this->{'socket'};
    my $select = IO::Select->new($socket);
    $this->{'select'} = $select;
    # Now read the banner
    my $read;
    my ($res, $resp ) = $this->read_resp();
    if( $res eq "OK" ){
	my @resp_lines = split /\r\n/,	$resp;
	if( pop(@resp_lines) eq "OK" ){
	    $this->{'connected'} = 1;
	    my $capab = join "\n", (@resp_lines);
	    return ("OK", $capab);
	}else{
	    return ("ERR", $resp);
	}
    }
}

sub authplain{
    my ($this, $user, $auth, $passwd) = @_;
    if( ! $this->{'connected'} ){
	return ("ERR", "call connect first");
    }
    if( $this->{'authenticated'} ){
	return ("ERR", "already authenticated");
    }
    my $socket = $this->{'socket'};
    my $authstring = $user . chr(0) . $auth . chr(0) . $passwd;
    $authstring = encode_base64($authstring,"");
    my $len = length($authstring);
    my $authline = "AUTHENTICATE \"PLAIN\" {$len+}\r\n";
    $authline .= $authstring ."\r\n";
#    print STDERR $authline ."\n";
    $socket->print( $authline );
    my ($res, $text) = $this->read_resp();
    if( $res eq "OK" ){
	if( $text eq "OK\r\n" ){
	    $this->{'authenticated'} = 1;
	    return ("OK","");
	}elsif( $text =~ /^NO (.*)$/ ){
	    return ("NO",$1 );
	}
    }else{
	return ($res, $text);
    }
}

sub logout{
    my $this = shift;
    if( ! $this->{'authenticated'} ){
	return("ERR", "authenticate first");
    }
    my $socket = $this->{'socket'};
    $socket->print( "LOGOUT\r\n" );

    my ($res, $text) = $this->read_resp();
    if( $res eq "OK" ){
	$this->{'authenticated'} = 0;
	$this->{'connected'} = 0;
    }
    return ($res, $text);
}

sub getScript{
    my ($this, $name) = @_;
    if( ! $this->{'authenticated'} ){
	return("ERR", "authenticate first");
    }
    my $socket = $this->{'socket'};
    $socket->print("GETSCRIPT \"$name\"\r\n");
    my ($res, $text) = $this->read_resp();
    return($res, $text);
}

sub putScript{
    my ($this, $name, $script) = @_;
    if( ! $this->{'authenticated'} ){
	return("ERR", "authenticate first");
    }
    my $socket = $this->{'socket'};
    my $len = length($script);
    my $sendbuffer = "PUTSCRIPT \"$name\" {$len+}\r\n$script\r\n";
    $socket->print($sendbuffer);
    my ($res, $text) = $this->read_resp();
    return($res, $text);
}

sub setActive{
    my ($this, $name) = @_;

    if( ! $this->{'authenticated'} ){
	return("ERR", "authenticate first");
    }
    
    my $socket = $this->{'socket'};
    $socket->print("SETACTIVE \"$name\"\r\n");
    my ($res, $text) = $this->read_resp();
    return($res, $text);
}

sub deleteScript{
    my ($this, $name) = @_;
    if( ! $this->{'authenticated'} ){
	return("ERR", "authenticate first");
    }
    my $socket = $this->{'socket'};
    $socket->print("DELSCRIPT \"$name\"\r\n");
    my ($res, $text) = $this->read_resp();
    return($res, $text);
}

sub listScripts{
#    my ($this) = @_;
#    if( ! $this->{'authenticated'} ){
#	 return("ERR", "authenticate first");
#    }
#    my $socket = $this->{'socket'};
#    $socket->print("LISTSCRIPTS\r\n");
#    my ($res, $response) = $this->read_resp();
    return ("ERR","not implemented");
}

sub read_resp{
    my $this = shift;
    my $socket = $this->{'socket'};
    my $select = $this->{'select'};
    my $buffer;
    my $read_buf;
    my $res = 1;
    my $line;
    my $err_string;
    my $read_script = 0;
    while( $line = <$socket> ){
	if(! $read_script){
            $buffer .= $line;
	}
	if( $line =~ /^\{(\d+)\}\r\n$/ ){
	    my $to_read = $1;
	    $buffer="";
	    while( ($to_read > 0) && ($res != 0) ){
		$res = read($socket, $read_buf, $to_read);
		$to_read = $to_read - $res;
		$buffer .= $read_buf; 
	    }
	    $read_script=1;
	    next;
        }elsif( $line =~ /^(OK).*$/ ){
	    return("OK", $buffer);
	}elsif( $line =~ /^BYE.*$/ ){
	    return("ERR","Server has closed connection");
        }elsif( $line =~ /^NO "(.*)"\r\n$/ ){
	    return("ERR",$1);
        }elsif( $line =~ /^NO (\{(\d+)\})?\r\n$/ ){
	    if( (defined $2) && ($2 > 0) ) {
		my $to_read = $2;
		while( ($to_read > 0) && ($res != 0) ){
		    $res = read($socket, $read_buf, $to_read);
		    $to_read = $to_read - $res;
		    $err_string .= $read_buf; 
		}
		return("ERR", $err_string);
	    }
	    return("ERR", "unknown error");
	}
    }
}
1;

