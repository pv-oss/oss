#!/usr/bin/perl
BEGIN{
   push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_pedagogic;
use Data::Dumper;

open(SHALLA,"/var/lib/squidGuard/db/BL/global_usage");
my $NAME='';
my $SHALLA={};
my @BL=();
my @WL=();
my $LANGS={};
my $TRANS= {};
my $CATDN= {};
my $oss = oss_pedagogic->new();

while(<SHALLA>)
{
	next if (/^#/);
	if(/^NAME:\s+(.*)/)
	{
	   $NAME=$1; 
	   $NAME=~s#/#-#;
	}
	elsif(/^NAME (..): (.*)/)
	{
		$SHALLA->{$NAME}->{NAME}->{$1} = $2;
		$LANGS->{$1} = 1;
	}
	elsif(/^DESC (..): (.*)/)
	{
		$SHALLA->{$NAME}->{DESC}->{$1} = $2;
	}
	elsif(/^DEFAULT_TYPE: (.*)/)
	{
		$SHALLA->{$NAME}->{TYPE} = $1;
	}
}
close SHALLA;
print Dumper($SHALLA);
foreach my $i (keys %$SHALLA)
{
    my $desc = '';
    foreach my $L ( keys %{$SHALLA->{$i}->{DESC}} )
    {
    	$desc .= 'DESC-'.$L.'='.$SHALLA->{$i}->{DESC}->{$L}."\n";
    }
    if( $SHALLA->{$i}->{NAME}->{EN} =~ /(.*)\/(.*)/ )
    {
	my $base = $1;
	my $sub  = $2;
	foreach my $L ( keys %{$SHALLA->{$i}->{NAME}} )
	{
		if( $SHALLA->{$i}->{NAME}->{$L} =~ /(.*)\/(.*)/ )
		{
			$desc .= 'NAME-'.$L.'='.$2."\n";
		}
		else
		{
			$desc .= 'NAME-'.$L.'='.$SHALLA->{$i}->{NAME}->{$L}."\n";
		}
	}
    	if( ! defined $CATDN->{$base} )
	{
		my $desc1 = '';
		foreach my $L ( keys %{$SHALLA->{$i}->{NAME}} )
		{
			if( $SHALLA->{$i}->{NAME}->{$L} =~ /(.*)\/(.*)/ )
			{
				$desc1 .= 'NAME-'.$L.'='.$1."\n";
			}
			else
			{
				$desc1 .= 'NAME-'.$L.'='.$SHALLA->{$i}->{NAME}->{$L}."\n";
			}
		}
    		$CATDN->{$base} = $oss->add_whitelist_category($base,$desc1);
	}
    	$oss->add_whitelist_category($sub,$desc,$CATDN->{$base});
    }
    else
    {
	foreach my $L ( keys %{$SHALLA->{$i}->{NAME}} )
	{
		$desc .= 'NAME-'.$L.'='.$SHALLA->{$i}->{NAME}->{$L}."\n";
	}
    	$oss->add_whitelist_category($SHALLA->{$i}->{NAME}->{EN},$desc);
    }
}
$oss->destroy();
