#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "path=s",
			"sessid=s",
                        );

system("test -e /tmp/tmp_squid_log_$options{'sessid'} && rm /tmp/tmp_squid_log_$options{'sessid'}");

my $file = `cat $options{'path'}`;
my @splt_file = split("\n",$file);
open STDOUT,">/tmp/tmp_squid_log_$options{'sessid'}";

START:
@splt_file = sort(@splt_file);
foreach my $i (@splt_file){
	if(!$splt_file[0]){
		shift(@splt_file);
		redo;
	}
}
my ($datea, $timea, $usera, $hosta, $urla) = split(' ',$splt_file[0]);

my @T = split /:/, $timea;
if( ($T[1]+5) ge 60 ){
	$T[0] = $T[0] + 1;
	$T[1] = ($T[1] + 5) % 5;
}else{
	$T[1] = $T[1] + 5;
}
my $time_limit = sprintf("%02d:%02d",   $T[0],$T[1]);

if( $urla =~ /^([0-9a-zA-Z]+)(:\/\/)([\.\-0-9a-zA-Z]+\/)(.*)/){
	$urla = $1.$2.$3;
}

shift(@splt_file);
my $size = scalar(@splt_file);
for(my $i=0; $i < $size; $i++){
	my ($date, $time, $user, $host, $url) = split(' ',$splt_file[$i]);
	if( $url =~ /^([0-9a-zA-Z]+)(:\/\/)([\.\-0-9a-zA-Z]+\/)(.*)/){
		$url = $1.$2.$3;
	}

	if($time gt $time_limit){
		last;
	}elsif(($datea eq $date) and ($time ge $timea) and ($time le $time_limit) and ($usera eq $user) and ($hosta eq $host) and ($urla eq $url)){
		delete $splt_file[$i];
	}
}

print $datea." ".$timea." ".$usera." ".$hosta." ".$urla."\n";

if(scalar(@splt_file)){
	goto START;
}
close(STDOUT);
