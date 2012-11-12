#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

use strict;
use MIME::Base64;
use POSIX;
use Data::Dumper;
use Encode ( 'encode', 'decode' );
use open ':utf8';
binmode STDIN, ':utf8';
binmode STDOUT,':utf8';
binmode STERR, ':utf8';

my $uid   = undef;
my $path  = undef;
my $all   = 0;
my $home  = '/home';
while(<STDIN>)
{
	# Clean up the line!
	chomp; s/^\s+//; s/\s+$//;
	my ( $key, $value ) = split / /,$_,2;
	$uid=$value  if( $key eq 'uid' );
	$path=$value if( $key eq 'path' );
	$all=$value  if( $key eq 'all' );
}
my @full  = split /\//, $path;

if ( $uid ne 'admin' )
{
        my @pw = getpwnam($uid);
        $home =  $pw[7];
}
my $OUT   = "<dir label=\"$home\" path=\"$home\">\n";

sub print_dir
{
	my $p  = shift;
	my $f  = shift;
	my $o  = shift || 0;
	$f =~ s/&/&amp;/mg; $f =~ s/</&lt;/mg; $f =~ s/>/&gt;/mg;
	$p =~ s/&/&amp;/mg; $p =~ s/</&lt;/mg; $p =~ s/>/&gt;/mg;
	if( $o )
	{
		$OUT .= '<dir label="'.$f.'" path="'.$p .'/'.$f.'"'.">\n";
	}
	else
	{
		$OUT .= '<dir label="'.$f.'" path="'.$p .'/'.$f.'"'."/>\n";
	}
}

sub print_file
{
	my $p  = shift;
	my $f  = shift;
	$f =~ s/&/&amp;/mg; $f =~ s/</&lt;/mg; $f =~ s/>/&gt;/mg;
	$p =~ s/&/&amp;/mg; $p =~ s/</&lt;/mg; $p =~ s/>/&gt;/mg;
	$OUT .= '<file label="'.$f.'" path="'.$p .'/'.$f.'"'."/>\n";
}

sub recursiv
{
	my $aktpath = shift;
	my @lpath   = split /\//, $aktpath;
        my $depth   = $#lpath;
	my @dirs  = ();
	my @files = ();
	opendir DIR, $aktpath;
	foreach (readdir(DIR))
	{
		next if( !$all && /^\./ );
		$_ = decode('UTF-8',$_);
		if( -f $aktpath.'/'.$_ )
		{
			push @files,$_;
		}
		elsif( -d $aktpath.'/'.$_ )
		{
			push @dirs,$_;
		}
	}
	close(DIR);
	if( defined $full[$depth+1] )
	{
		print_dir($aktpath,$full[$depth+1],1);
		recursiv("$aktpath/".$full[$depth+1]);
		$OUT .= "</dir>\n";
	}
	foreach (sort (@dirs))
	{
		next if( $_ eq '.' || $_ eq '..' );
		next if( $full[$depth+1] eq $_ );
		print_dir($aktpath,$_,0);
	}
	if( $aktpath eq $path ) {
		foreach (sort (@files))
		{
			print_file($aktpath,$_);
		}
	}

}

recursiv($home);
$OUT .= "</dir>";
print $OUT;
