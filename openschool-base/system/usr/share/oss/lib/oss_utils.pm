=head1 NAME
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

 oss_utils

=head1 PREFACE

 This package contains some helper sripts.

=head1 SYNOPSIS

 #!/usr/bin/perl 
 
 BEGIN{ push @INC,"/usr/share/oss/lib/"; }
 
 use oss_utils;
 

=head1 DESCRIPTION


=over 2

=cut

require Exporter;
package oss_utils;

use strict;
use Socket;
use Data::Dumper;
use Time::Local;
use Digest::MD5  qw(md5_hex);
use MIME::Base64;
use Crypt::SmbHash;
use Storable qw(thaw freeze);
use IPC::Open2;
use Encode;
use utf8;
use vars qw(
	@ISA
	@EXPORT
	$VERSION
	@LANGUAGES
	);


@ISA = qw(Exporter);

@EXPORT = qw(
	@LANGUAGES
	&check_mac
	&cmd_pipe
	&contains
	&get_name_of_dn
	&get_time_zones
	&get_parent_dn
	&getLanguages
	&getSocket
        &getConnect
	&getTimeZones
	&group_diff
	&hash_to_xml
	&hash_to_text
	&hash_password
	&parse_file
	&get_file
	&get_files_recursive
	&make_array_attributes
	&normalize
	&reply_xml
	&string_to_ascii
	&string_to_xml
	&subscribe_folders
	&unsubscribe_folders
	&utf7_decode
        &utf7_encode
	&write_file
	&write_tmp_file
	&xml_time
	&check_domain_name_for_proxy
	&date_format_convert
);
$VERSION = '0.01';
# Debug only
#use Data::Dumper;

# Privat Variable
# SERVER
my $server_ip = "localhost";
my $server_port = "33333";
my $proto = 'tcp';
# UNIX
my $rendezvous = '/var/run/sessiond.sock';
my $readcount = 4096;
my $OXROOT    = '/var/www/html/openxchange';
# SSL
my $ssl_key_file = '/etc/ssl/servercerts/schoolserverkey.pem';
my $ssl_cert_file = '/etc/ssl/servercerts/schoolservercert.pem';
my $ssl_ca_file = '/etc/ssl/certs/YaST-CA.pem';
my $ssl_use_cert = 1; 
my $ssl_verify_mode = '0x01';
my @LANGUAGES = ( 'DE', 'CZ', 'EN', 'ES', 'FR', 'HU', 'IT', 'RO', 'SL' );
#######################################################################################
# End header                                                                          #
#######################################################################################

=item B<check_mac(MAC-ADDRESSE)>

Check if the mac address is good.

EXAMPLE:

    if( ! check_mac($mac) )
    {
	print "Mac address is invalid".
    }
=cut

sub check_mac($)
{
	my $hw = shift;
	my $m  = '[0-9A-F][0-9A-F]';
	if( $hw !~ /^$m:$m:$m:$m:$m:$m$/i )
	{
		return 0;
	}
	return 1;
}
#-----------------------------------------------------------------------

=item B<cmd_pipe($cmd,$arg)>

Pipes the arguments $arg tru the command $cmd

EXAMPLE:

  my $arg = "sn Varkoly
givenname Peter
role teacher
class 5A
class 7A
birthday 1967-04-17
";
   my $cmd = "/usr/sbin/add_user -";

   my $err = cmd_pipe($cmd,$arg); 

=cut 

sub cmd_pipe
{
        my $cmd = shift;
        my $arg = shift;
        my $err = "";
	local (*Reader,*Writer);
	my $pid = open2(\*Reader,\*Writer, $cmd);

	print Writer $arg;
	close(Writer);
        while(<Reader>) {
                    $err .= $_;
        }
	close(Reader);
	waitpid($pid,0);
        return "$err";
}
#-----------------------------------------------------------------------

=item B<contains($a,\@b)>

Returns true if the array @b contains the value $a;

=cut

sub contains {
    my $a = shift;
    my $b = shift;
    foreach(@{$b}){
        if($a eq $_) {
                return 1;
        }
    }
    return 0;
}

=item B<get_time_zones()>

Returns a hash with the timezones informations

EXAMPLE:

  my $timeZones = get_time_zones();

  print $timeZones->{default}."\n";
  foreach my $zone (@{$timeZones->{zones}}) {
    print "  $zone\n";
  }

=cut

sub get_time_zones() {
    my $tzf           =  '/usr/share/zoneinfo/zone.tab';
    my @timezones;
    my @dflt_timezone =  parse_file("/etc/sysconfig/clock", "TIMEZONE=");
    my $defaultTZ     =  $dflt_timezone[0];
    $defaultTZ        =~ s/\"//g;

    open(TZ, "$tzf") || return undef;
    while(<TZ>) {
        next if /^#/;
        next if /^\s*$/;
        m/(\w\w)\s+(.*?)\s+(.*?)\s+.*/;
        push @timezones, $3;
    }
    @timezones = sort(@timezones);
    #add the Standard 3 Letter timezones just to make sure
    push @timezones,( "ACT", "AET", "AGT", "ART", "AST", "BET", "BST", "CAT",
            "CET", "CNT", "CST", "CTT", "EAT", "ECT", "EET", "EST", "GMT",
            "HST", "IET", "IST", "JST", "MET", "MIT", "MST", "NET", "NST",
            "PLT", "PNT", "PRT", "PST", "SST", "UTC", "VST", "WET", "Etc/GMT",
            "Etc/GMT+1", "Etc/GMT+2", "Etc/GMT+3", "Etc/GMT+4", "Etc/GMT+5",
            "Etc/GMT+6", "Etc/GMT+7", "Etc/GMT+8", "Etc/GMT+9", "Etc/GMT+10",
            "Etc/GMT+11", "Etc/GMT+12", "Etc/GMT-1", "Etc/GMT-2", "Etc/GMT-3",
            "Etc/GMT-4", "Etc/GMT-5", "Etc/GMT-6", "Etc/GMT-7", "Etc/GMT-8",
            "Etc/GMT-9", "Etc/GMT-10", "Etc/GMT-11", "Etc/GMT-12",
            "Etc/GMT-13", "Etc/GMT-14", "Etc/UCT", "Etc/UTC");

   return { default=>$defaultTZ, zones=>\@timezones };

}
#-----------------------------------------------------------------------

=item B<get_name_of_dn(dn)>

Returns the last tag of an DN.

EXAMPLE:

my $uid = get_name_of_dn('uid=varkpete,ou=people,dc=extis,dc=de');


=cut

sub get_name_of_dn($) {
    my $dn      = shift;

    my $first_tag = (split /,/,$dn)[0];
    if( defined $first_tag && $first_tag ne '' ) {
      return (split /=/,$first_tag)[1];
    }
    return undef;
}
#-----------------------------------------------------------------------

=item B<get_parent_dn(dn)>

Returns the parent of an DN.

EXAMPLE:

my $base = get_parent_dn('uid=varkpete,ou=people,dc=extis,dc=de');


=cut

sub get_parent_dn($) {
    my $dn      = shift;

    my ($dummy, $parent) = split /,/,$dn,2;

    return $parent;
}
#-----------------------------------------------------------------------

=item B<group_diff(\@old_groups,\@new_groups)>

Returns the array pointers.

=cut

sub group_diff {
    my $old   = shift;
    my $new   = shift;
    my @toadd = ();
    my @todel = ();
    foreach(@{$old}) {
        if( !contains($_,$new)) {
           push @todel,$_;
        }
    }
    foreach(@{$new}) {
        if( !contains($_,$old)) {
           push @toadd,$_;
        }
    }
    return ( \@todel, \@toadd );
}
#-----------------------------------------------------------------------

# Subroutine to write a hash as an XML 
sub hash_to_xml{
    my $hash   = shift;
    my $oc     = shift || 0;
    my $xml    = "";
    my $ident  = '  ';

    foreach my $key ( keys %$hash ) {
      $xml .= "<dn dn=\"$key\">\n";
	foreach my $att ( keys %{$hash->{$key}} ) {
	    next if( $att eq 'objectclass' && ! $oc );
	    $ident  = '  ';
            foreach my $value (@{$hash->{$key}->{$att}}){
		  $xml .= "$ident<$att>".string_to_xml($value)."</$att>\n";
	    }
	}
      $xml .= "</dn>\n";
    }
    return $xml;
}
#-----------------------------------------------------------------------

# Subroutine to write a hash as text 

sub hash_to_text{
    my $hash   = shift;
    my $oc     = shift || 0;
    my $text   = "";
    my $ident  = '  ';

    foreach my $key ( keys %$hash ) {
        $text .= $key."\n";
	foreach my $att ( keys %{$hash->{$key}} ) {
	    next if( $att eq 'objectclass' && ! $oc );
            foreach my $value (@{$hash->{$key}->{$att}}){
	        $text .= "$att $value\n";
	    }
	}
	$text .= "\n";
    }
    return $text;
}
#-----------------------------------------------------------------------

# Subroutine to parse the connect parameters from STDIN
sub getConnect
{
    my $connect = shift;
    my $key     = shift;
    my $value   = shift;

    if( $key eq "aOID" )
    {
            $connect->{aOID} = $value;
	    return 1;
    }
    elsif( $key eq "sDN" )
    {
            $connect->{sDN} = $value;
	    return 1;
    }
    elsif( $key eq "aDN" )
    {
            $connect->{aDN} = $value;
	    return 1;
    }
    elsif( $key eq "aUID" )
    {
            $connect->{aUID} = $value;
	    return 1;
    }
    elsif( $key eq "aPW" )
    {
            $connect->{aPW} = $value;
	    return 1;
    }
    return 0;
}

#-----------------------------------------------------------------------
=item B<getLanguages([Default Languages])>

Returns an array referenc to a list of the languages. If no default language is given
the system time zone is the default.

EXAMPLE:

  my $languages = getLanguages('DE');

=cut

sub getLanguages
{
    my $default       = shift || '';
    my @L             = ();
    if( $default eq '' )
    {
        $default = `. /etc/sysconfig/language ; echo \$RC_LANG`;
	$default = substr($default,0,5);
    }
    if( ! contains( $default, \@LANGUAGES ) )
    {
    	$default = uc( substr($default,0,2) );
    }
    push @L, @LANGUAGES, '---DEFAULTS---', $default;
    return \@L;
}

#-----------------------------------------------------------------------
sub getSocket {

    my ($mode) = @_;
    my $sock;

    if( $mode == 1) {
        # unix socket

        socket($sock, PF_UNIX, SOCK_STREAM,0);
        connect($sock, sockaddr_un($rendezvous));
    } elsif ($mode == 2) {
        # ssl socket
        #$IO::Socket::SSL::DEBUG=1;

        $sock = IO::Socket::SSL->new( PeerAddr => $server_ip,
                                      PeerPort => $server_port,
                                      Proto    => $proto,
                                      SSL_key_file => $ssl_key_file,
                                      SSL_cert_file => $ssl_cert_file,
                                      SSL_ca_file => $ssl_ca_file,
                                      SSL_use_cert => $ssl_use_cert,
                                      SSL_verify_mode => $ssl_verify_mode );

    } elsif ($mode == 3) {
        # plain socket
        use IO::Socket;
        $sock = new IO::Socket::INET (
                                         PeerAddr => $server_ip,
                                         PeerPort => $server_port,
                                         Proto => $proto,
                                         );
    }

    if( ! defined $sock ) {
        print STDERR "Can not build up Socket!\n";
        print STDERR "ERRNO=<$!> in getSocket. Can not connect do SessionD\n";
        exit;
    }

    #print STDERR "building socker -> ".$sock."\n";

    return $sock;
}
#-----------------------------------------------------------------------
=item B<getTimeZones([Default Time Zone])>

Returns an array referenc to a list of the time zones. If no default time zone is given
the system time zone is the default.

EXAMPLE:

  my $timezones = getTimeZones('Europe/Berlin');

=cut

sub getTimeZones
{
    my $default       = shift || `. /etc/sysconfig/clock ; echo \$TIMEZONE`; chomp $default;
    my $tzf           =  '/usr/share/zoneinfo/zone.tab';
    my @timezones;

    open(TZ, "$tzf") || return undef;
    while(<TZ>) {
        next if /^#/;
        next if /^\s*$/;
        m/(\w\w)\s+(.*?)\s+(.*?)\s+.*/;
        push @timezones, $3;
    }
    @timezones = sort(@timezones);
    #add the Standard 3 Letter timezones just to make sure
    push @timezones,( "ACT", "AET", "AGT", "ART", "AST", "BET", "BST", "CAT",
            "CET", "CNT", "CST", "CTT", "EAT", "ECT", "EET", "EST", "GMT",
            "HST", "IET", "IST", "JST", "MET", "MIT", "MST", "NET", "NST",
            "PLT", "PNT", "PRT", "PST", "SST", "UTC", "VST", "WET", "Etc/GMT",
            "Etc/GMT+1", "Etc/GMT+2", "Etc/GMT+3", "Etc/GMT+4", "Etc/GMT+5",
            "Etc/GMT+6", "Etc/GMT+7", "Etc/GMT+8", "Etc/GMT+9", "Etc/GMT+10",
            "Etc/GMT+11", "Etc/GMT+12", "Etc/GMT-1", "Etc/GMT-2", "Etc/GMT-3",
            "Etc/GMT-4", "Etc/GMT-5", "Etc/GMT-6", "Etc/GMT-7", "Etc/GMT-8",
            "Etc/GMT-9", "Etc/GMT-10", "Etc/GMT-11", "Etc/GMT-12",
            "Etc/GMT-13", "Etc/GMT-14", "Etc/UCT", "Etc/UTC");
    push @timezones, '---DEFAULTS---';
    push @timezones, $default;
    return \@timezones;

}
#-----------------------------------------------------------------------

=item B<hash_password($mech, $password)>

Hash user password for LDAP users. This subroutine proviedes the next
hash types: crypt, md5, smd5, sha, ssha 

EXAMPLE:

  my $hash = hash_password('crypt','12345678');

=cut

sub hash_password {

    my ($mech, $password) = @_;
    $mech = lc($mech);
    if ($mech  eq "crypt" ) {
        my $salt =  pack("C2",(int(rand 26)+65),(int(rand 26)+65));
        $password = crypt $password,$salt;
        $password = "{crypt}".$password;
    }
    elsif ($mech eq "md5") {
        my $ctx = new Digest::MD5();
        $ctx->add($password);
        $password = "{md5}".encode_base64($ctx->digest, "");
    }
    elsif ($mech eq "smd5") {
        my $salt =  pack("C5",(int(rand 26)+65),
                              (int(rand 26)+65),
                              (int(rand 26)+65),
                              (int(rand 26)+65),
                              (int(rand 26)+65)
                        );
        my $ctx = new Digest::MD5();
        $ctx->add($password);
        $ctx->add($salt);
        $password = "{smd5}".encode_base64($ctx->digest.$salt, "");
    }
    elsif( $mech eq "sha") {
        $password = sha1($password);
        $password = "{sha}".encode_base64($password, "");
    }
    elsif( $mech eq "ssha") {
        my $salt =  pack("C5", (int(rand 26)+65),
                               (int(rand 26)+65),
                               (int(rand 26)+65),
                               (int(rand 26)+65),
                               (int(rand 26)+65)
                        );
        $password = sha1($password.$salt);
        $password = "{ssha}".encode_base64($password.$salt, "");
    }
    return $password;
}
#----------------------------------------------------------------------

=item B<normalize(\@array)>

Normalize a array. I.e. removes duplicate entries;

EXAMPLE:

  my @myarray = ('a','a','b','c');

  my $normalized_has = normalize(\@myarray);

=cut

sub normalize($)
{
    my $a = shift;
    my $b = {};
    my @c = map {
            if( defined $b->{$_} )
            {
               $_ = undef;
            }
            else
            {
              $b->{$_} = $_;
            }
         } @{$a};

     my @d = ();
     foreach my $i (@c)
     {
         if( defined $i )
         {
             push @d, $i;
         }
     }
     return \@d;
}
#----------------------------------------------------------------------


=item B<parse_file(filename,searchfor)>

Parse a file for some attributes.

EXAMPLE:

  ($LDAP_BASE, $LDAP_SERVER, $LDAP_PORT) = parse_file($ldap_conf, "BASE", "HOST", "PORT");

=cut

sub parse_file {
    my $file = shift;
    my @searchfor = @_;

    my @erg = ();
    my $found = 0;
    my @a = split( /\n/, get_file($file));

    for(my $i=0; $i<=$#searchfor; $i++) {
        foreach (@a) {
            if($_ =~ /^$searchfor[$i]/i) {
                $_ =~ s/$searchfor[$i]\s*(.*)/$1/i;
                chomp($_);
		s/^"//; s/"$//;
		s/^'//; s/'$//;
                push @erg, $_;
                $found = 1;
                last;
            }
        }
        if($found != 1) {
            push @erg, "";
        } else {
            $found = 0;
        }
    }
    return @erg;
}
#-----------------------------------------------------------------------

=item B<get_file(filename)>

Reads a file into a variable.

EXAMPLE:

  my $file = get_file('/etc/hosts');

=cut

sub get_file($) {
    my $file     = shift;
    return undef if( ! -e $file ); 
    my $content  = '';
    local *F;
    open F, $file || return undef;
    while( <F> )
    {
       $content .= $_;
    }
    return $content;
}

#-----------------------------------------------------------------------

sub get_files_recursive {
    my $currentdir = shift;
    my $allFiles   = shift;;

    opendir(DIR,$currentdir) || return undef;

    my @ret = readdir(DIR);
    foreach my $f ( @ret ) {
        next if $f =~ /^\./;
        my $fqp = $currentdir."/".$f;
        if( -d $fqp ) {
            get_files_recursive($fqp,$allFiles);
        } else {
            push @$allFiles, $fqp;
        }
    }

    closedir(DIR);
    return 1;
}

#-----------------------------------------------------------------------

=item B<string_to_ascii(UTF-8-String,[Alias=0|1])>

Converts an UTF-8 string into an US-ascii-7 string. Removes the non convertable characters.
If Alias is set to 1 the white spaces willbe replaced with 1 ".". 

EXAMPLE:

  my $alias = string_to_ascii( $sn.'.'.$givenname, 1 );

=cut
sub string_to_ascii {
    my $str   = shift;
    my $alias = shift || 0;
    my ( $STRING_CONVERT_TYPE ) =  parse_file("/etc/sysconfig/schoolserver", "SCHOOL_STRING_CONVERT_TYPE=");

    if( ! utf8::is_utf8($str) )
    {
        utf8::encode($str);
    }

    if( $STRING_CONVERT_TYPE eq 'simple' )
    {
       $str =~ s/ä/a/g;
       $str =~ s/ü/u/g;
       $str =~ s/ö/o/g;
       $str =~ s/Ä/A/g;
       $str =~ s/Ü/U/g;
       $str =~ s/Ö/O/g;
       $str =~ s/Ö/O/g;
    }
    else
    {
       $str =~ s/ä/ae/g;
       $str =~ s/ü/ue/g;
       $str =~ s/ö/oe/g;
       $str =~ s/Ä/AE/g;
       $str =~ s/Ü/UE/g;
       $str =~ s/Ö/OE/g;
       $str =~ s/Ö/OE/g;
    }
    $str =~ s/ß/s/g;
    $str =~ s/ű/u/g;
    $str =~ s/Ű/U/g;
    $str =~ s/ő/o/g;
    $str =~ s/Ő/O/g;
    $str =~ s/á/a/g;
    $str =~ s/ă/a/g;
    $str =~ s/â/a/g;
    $str =~ s/è/e/g;
    $str =~ s/é/e/g;
    $str =~ s/í/i/g;
    $str =~ s/î/i/g;
    $str =~ s/ó/o/g;
    $str =~ s/ô/o/g;
    $str =~ s/ú/u/g;
    $str =~ s/Á/A/g;
    $str =~ s/Ă/A/g;
    $str =~ s/Â/A/g;
    $str =~ s/É/E/g;
    $str =~ s/Í/I/g;
    $str =~ s/Î/I/g;
    $str =~ s/Ó/O/g;
    $str =~ s/Ú/U/g;
    $str =~ s/ç/c/g;
    $str =~ s/č/c/g;
    $str =~ s/ş/s/g;
    $str =~ s/ţ/t/g;
    $str =~ s/Ş/S/g;
    $str =~ s/Ţ/T/g;

    if($alias)
    {
       $str =~ s/\s+/ /g;
       $str =~ s/ /./g;
       $str =~ s/[^a-zA-Z0-9-_\.]//g;
    }
    else
    {
      $str =~ s/[\W]//g;
    }
    return $str;
}

#-----------------------------------------------------------------------

=item B<string_to_xml(UTF-8-String)>

Subroutine to encode special characters for XML streams

=cut

sub string_to_xml
{
    $_ = shift;

    s/&/&amp;/g;
    s/"/&quot;/g;
    s/'/&apos;/g;
    s/</&lt;/g;
    s/>/&gt;/g;

    return $_;
} 
#-----------------------------------------------------------------------

=item B<subscribe_folders(Users DN,List of the folders)>

Subscribes a list of folders for a user. This will be done directly into
the filesystem and not thru IMAP protocol

EXAMPLE:

   subscribe_folders('uid=admin,ou=people,dc=schule,dc=de',[ 'sysadmins', 'teachers' ] );

=cut

sub subscribe_folders($$)
{
  my $dn      = shift;
  my $folders = shift;
  my $uid     = get_name_of_dn($dn);

  #searching for subscribed file
  $uid =~ /^(.)/;
  my $subfile = "/var/lib/imap/user/$1/$uid.sub";
  if( $1 =~ /[0-9]/ )
  {
    $subfile = "/var/lib/imap/user/q/$uid.sub";
  }

  my $subs = get_file($subfile) || '' ;

  my @lsubs = split /\t\n/, $subs;
  
  foreach( @{$folders} )
  {
    s/\//./g;
    if( ! contains( $_, \@lsubs ) )
    {
      $subs = "$_\t\n".$subs;
    }
  }
  write_file($subfile, $subs );
  my ($login,$pass,$uidnumber,$gidnumber) = getpwnam('cyrus');
  chown $uidnumber,$gidnumber,$subfile; 
}

=item B<unsubscribe_folders(Users DN,List of the folders)>

Unsubscribes a list of folders for a user. This will be done directly into
the filesystem and not thru IMAP protocol

EXAMPLE:

   unsubscribe_folders('uid=admin,ou=people,dc=schule,dc=de',[ 'sysadmins', 'teachers' ] );

=cut

sub unsubscribe_folders($$)
{
  my $dn      = shift;
  my $folders = shift;
  my $uid     = get_name_of_dn($dn);

  #searching for subscribed file
  $uid =~ /^(.)/;
  my $subfile = "/var/lib/imap/user/$1/$uid.sub";
  if( $1 =~ /[0-9]/ )
  {
    $subfile = "/var/lib/imap/user/q/$uid.sub";
  }

  my $subs = get_file($subfile);

  foreach( @{$folders} )
  {
    $subs =~ s/$_\t\n//m;
  }
  write_file($subfile, $subs );
}

#-----------------------------------------------------------------------

=item B<write_file(filename,var)>

Writes a scalar varibale into a file.

EXAMPLE:

  write_file('/tmp/12345',$TMP);

=cut

sub write_file($$) {
  my $file = shift;
  my $out  = shift;
  local *F;
  open F, ">$file" || die "Couldn't open file '$file' for writing: $!; aborting";
  local $/ unless wantarray;
  print F $out;
  close F;
}

#-----------------------------------------------------------------------

#-----------------------------------------------------------------------

=item B<write_tmp_file(var)>

Writes a scalar varibale into a temporary file.

EXAMPLE:

  my $tmp = write_tmp_file($TMP);

=cut

sub write_tmp_file($) {
  my $out  = shift;

  my $file = `/bin/mktemp /tmp/ossXXXXXXXX`;
  chomp $file;

  local *F;
  open F, ">$file" || die "Couldn't open file '$file' for writing: $!; aborting";
  local $/ unless wantarray;
  print F $out;
  close F;

  return $file;
}

#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
sub reply_xml {
    my $xml = shift;
    my $out = '';

    $out    = "<reply>\n";
    foreach my $line ( split /\n/,$xml ) {
      $out .= "  ".$line."\n";  
    }
    $out .= "</reply>\n";
    return $out;
}

#-----------------------------------------------------------------------

=item B<xml_time()>

Delivers the actual time in xml format.

EXAMPLE:

   my $time = xml_time();

=cut

sub xml_time()
{
    my  $timezone = `/bin/date +%:z`; chomp $timezone;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    return sprintf('%4d-%02d-%02d %02d:%02d:%02d.%s', $year+1900,$mon+1,$mday,$hour,$min,$sec,$timezone);
}


#-----------------------------------------------------------------------

=item B<make_array_attributes($hash)>

Makes array attributes from newline separated lists by following ldap attributes:

        member
        memberOf
        memberUid
        newmailAcceptAddress
        newmailForwardAddress
        mailAcceptAddress
        mailForwardAddress
	rasaccess
	class
	newgroup
	group

=cut

sub make_array_attributes($)
{
        my $hash = shift;
        foreach(keys %$hash )
        {
                if(/^member|memberOff|memberUid|newmember|group|newgroup|rasaccess|class$/i || /mailAcceptAddress|mailForwardAddress$/i)
                {
                        my @a = split /\n/, $hash->{$_};
			if( scalar @a )
			{
                        	$hash->{$_} = \@a;
			}
			else
			{
				delete $hash->{$_};
			}
                }
        }
}

#----------------------------------------------------------------------------

#-----------------------------------------------------------------------
sub mustENC($) {
    my $c = shift;
    return ( $c =~ /[\x00-\x1f]/ ) || ( ord($c) > 127 );
}
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
sub utf7_encode($) {
    # see rfc 2060
    my $str = shift;
    Encode::_utf8_on($str);

    my $nstr = "";
    for(my $i=0; $i<length($str); $i++) {
        my $l = substr($str,$i,1);
        if( mustENC($l) ) {
            my $allenc = "";
            while( mustENC($l) ) {
                $allenc .= $l;
                $l = substr($str,++$i,1);
            }

            $i--;
            # make 16 bit representation of allenc (UCS-2)
            my @chars = unpack( "U*", $allenc);
            $allenc = pack( "n*", @chars );

            my $enc = encode_base64( $allenc ,"");
            $enc =~ s/=//g;
            $enc =~ s/\//,/g;
            $nstr .= "&".$enc."-";
        } elsif( $l eq "&" ) {
            $nstr .= $l."-";
        } else {
            $nstr .= $l;
        }
    }

    return $nstr;
}
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
sub utf7_decode($) {
    my $str = shift;

    #print STDERR "STR=$str\n";
    my $nstr = "";
    foreach my $token ( split(/-/, $str, -1) ) {
        #print STDERR "TOK=$token\n";
        if( $token =~ /&/ ) {
            $token =~ /(.*)&(.*)/;
            if( ! defined $2 || $2 eq "" ) {
                $token = $1."&";
            } else {
                my $foo = $2;
                my $prefix = $1;
                $foo =~ s/,/\//;
                # pad with "=" to make base64 happy
                my $num = 4 - ( length($foo) % 4 );
                for( my $i=0; $i < $num && $num < 4; $i++ ){
                    $foo .= "=";
                }
                my $decode = decode_base64($foo);
                # each char is 16bit (UCS-2 AFAIK)
                my @chars = unpack("n*", $decode );
                # generate the corresponding Unicode String in Perl's
                # internal encoding
                $decode = pack("U*", @chars);
                $token = $prefix.$decode;
            }
        } else {
            $token .= "-";
        }
        $nstr .= $token;
    }
    $nstr =~ s/\-$// ;

    # remove binary \0 trash
    $nstr =~ s/\0//g;

#    $nstr = Encode::encode("utf-8",$nstr);
    return $nstr;
}
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
sub check_domain_name_for_proxy
{
        my $domain_list = shift;
	my @good_doomain_list;
        my @bad_domain_list;

        foreach my $domain_name (@$domain_list){
                if($domain_name =~ /^([\-0-9a-zA-Z]+)\.+([\-0-9a-zA-Z]+)\.+([a-zA-Z]+)$/){
			if($domain_name =~ /^((www[0-9]{0,10}\.)|(ftp[0-9]{0,10}\.))([\-0-9a-zA-Z]+)\.+([a-zA-Z]+)$/){
                                $domain_name =~ s/www[0-9]{0,10}.//;
                                $domain_name =~ s/ftp[0-9]{0,10}.//;
                                push @good_doomain_list, $domain_name;
                        }else{
                                push @good_doomain_list, $domain_name;
                        }
		}elsif($domain_name =~ /^([\-0-9a-zA-Z]+)\.+([a-zA-Z]+)$/){
			push @good_doomain_list, $domain_name;
                }else{
                        push @bad_domain_list, $domain_name;
                }
        }

	return ( \@good_doomain_list, \@bad_domain_list)
}

=item B<$oss->date_format_convert("$lang","$date")>

EXAMPLE :  $oss->date_format_convert("DE", "2011-06-21");

=cut

sub date_format_convert
{
        my $lang = shift;
        my $date = shift;
        my $new_date = '';

        my @splt_date = split("-",$date);
        if(($lang eq "DE") or ($lang eq "RO")){
                $new_date = "$splt_date[2].$splt_date[1].$splt_date[0]";
        }elsif($lang eq "HU"){
                $new_date = "$splt_date[0].$splt_date[1].$splt_date[2]";
        }else{
                $new_date = $date;
        }

        return $new_date;
}

1;
