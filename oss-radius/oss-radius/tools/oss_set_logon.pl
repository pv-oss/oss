#!/usr/bin/perl 

BEGIN { push @INC, "/usr/share/oss/lib" }

use strict;
use oss_utils;
use oss_base;
use Data::Dumper;

my $uid = shift;
my $mac = shift;
my @changes  = ();
my @delconf  = ();
my $result   = undef;

print STDERR "$uid $mac\n";
$mac =~ /(..)(..)(..)(..)(..)(..)/;
$mac = uc("$1:$2:$3:$4:$5:$6");

my $oss = oss_base->new( { aDN => "uid=admin,ou=people,dc=real-euro,dc=de", aPW => "mg*314" } );

my $udn = $oss->get_user_dn($uid);
my $wdn = $oss->get_host($mac);
my $ip  = $oss->get_ip_of_host($wdn);
my $ue  = $oss->get_entry( $udn, 1 );
my $we  = $oss->get_entry( $wdn, 1 );

print STDERR "$udn : $wdn : $mac : $ip\n";
system("date >> /tmp/radius");
system("echo '$udn : $wdn : $mac : $ip ' >> /tmp/radius");
my $envr='';
foreach my $i ( keys %ENV )
{
	$envr .= $i.'->'.$ENV{$i}."\n";
}
system("echo '$envr' >> /tmp/radius");

my @confs    = $ue->get_value('configurationValue');
foreach my $v (@confs)
{
   if( $v =~ /^LOGGED_ON=.*/ )
   {
	push @delconf, $v;
   }
}
if( scalar(@delconf) ){
	push @changes,  delete => [ configurationValue => \@delconf ] ;
}
push @changes,  add => [ configurationValue => "LOGGED_ON=$ip" ] ;

$result = $oss->{LDAP}->modify( $udn , changes => \@changes );
if( $result->code )
{
	$oss->ldap_error($result);
	print STDERR $oss->{ERROR}->{code}."\n";
	print STDERR $oss->{ERROR}->{text}."\n";
}

print STDERR Dumper(\@changes); 
 
@confs    = $we->get_value('configurationValue');
@changes  = ();
@delconf  = ();

foreach my $v (@confs)
{
   if( $v =~ /^LOGGED_ON=.*/ )
   {
	push @delconf, $v;
   }
}
if( scalar(@delconf) ){
	push @changes,  delete => [ configurationValue => \@delconf ] ;
}
push @changes,  add => [ configurationValue => "LOGGED_ON=$uid" ] ;

$result = $oss->{LDAP}->modify( $wdn , changes => \@changes );
if( $result->code )
{
	$oss->ldap_error($result);
	print STDERR $oss->{ERROR}->{code}."\n";
	print STDERR $oss->{ERROR}->{text}."\n";
}
print STDERR Dumper(\@changes); 

$oss->destroy;

