#!/usr/bin/perl
use strict;
use Data::Dumper;

open(SHALLA,"BL/global_usage");
my $NAME='';
my $SHALLA={};
my @BL=();
my @WL=();
my $LANGS={};
my $TRANS= {
		'DE' => {  
				DESC => {
						bad        => 'Eigene Blackliste',
						good       => 'Eigene Whiteliste',
						'in-addr'  => 'IP-Adressen',
						all        => 'Alle andere Domains'
				},
				bad        => 'Blackliste',
				good       => 'Whiteliste',
				'in-addr'  => 'IP-Adressen',
				all        => 'Der Rest'
			},
		'EN' => {  
				DESC => {
						bad        => 'Own Blacklist',
						good       => 'Own Whitelist',
						'in-addr'  => 'IP-Addresses',
						all        => 'All other domains'
				},
				bad        => 'Blacklist',
				good       => 'Whitelist',
				'in-addr'  => 'IP-Addresses',
				all        => 'The Rest'
			}

				
	   };

while(<SHALLA>)
{
	next if (/^#/);
	chomp;
	if(/^NAME:\s+(.*)/)
	{
	   $NAME=$1; 
	   $NAME=~s#/#-#;
	}
	elsif(/^NAME (..):\s+(.+)$/)
	{
		$SHALLA->{$NAME}->{NAME}->{$1} = $2;
		$LANGS->{$1} = 1 if ( $1 ne 'RU' );
	}
	elsif(/^DESC (..):\s+(.+)$/)
	{
		$SHALLA->{$NAME}->{DESC}->{$1} = $2;
	}
	elsif(/^DEFAULT_TYPE:\s+(.+)$/)
	{
		$SHALLA->{$NAME}->{TYPE} = $1;
	}
}
print Dumper($SHALLA);
close SHALLA;
foreach my $L (keys %$LANGS)
{
    open(LANG,">usr/share/lmd/lang/squidguard_$L.ini");
    print LANG "[squidGuard]\n";
    for my $i ( 'good', 'bad', 'all', 'in-addr' )
    {
	    if( $TRANS->{$L}->{$i} )
	    {
		print LANG $i.'='.$TRANS->{$L}->{$i}."\n";
		print LANG $i.'-DESC='.$TRANS->{$L}->{DESC}->{$i}."\n";
	    }
    }
    foreach my $i (keys %$SHALLA)
    {
	if( defined $SHALLA->{$i}->{NAME}->{$L} )
	{
        	print LANG "$i=".$SHALLA->{$i}->{NAME}->{$L}."\n";
	}
	if( defined $SHALLA->{$i}->{DESC}->{$L} )
	{
	        print LANG "$i-DESC=".$SHALLA->{$i}->{DESC}->{$L}."\n";
	}
	if( $L eq 'DE' )
	{
		if( $SHALLA->{$i}->{TYPE} eq 'black' )
		{
			push @BL, $i;
		}
		else
		{
			push @WL, $i; 
		}
	}
    }
    close LANG;
}
open(OUT,">usr/share/lmd/alibs/squidGuard/blacklists");
print OUT join "\n",sort(@BL);
close OUT;
open(OUT,">usr/share/lmd/alibs/squidGuard/whitelists");
print OUT join "\n",sort(@WL);
close OUT;
print Dumper(\@BL);
##print Dumper(\@WL);
#print Dumper($LANGS);
