# LMD Template modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package Translation;

use strict;
use oss_base;
use oss_utils;
use DBI;
use DBI qw(:utils);
use vars qw(@ISA);
@ISA = qw(oss_base);
use Data::Dumper;

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
		"enhance",
		"edit",
		"apply",
		"search",
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Enhace/Edit Transalation' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'Settings' },
		 { order        => 40 },
		 { variable     => [ "string",      [ type => "string" , readonly => undef ] ] },
		 { variable     => [ "section",     [ type => "string" , readonly => undef] ] },
		 { variable     => [ "sections",    [ type => "popup" ] ] },
		 { variable     => [ "lang",        [ type => "popup" ] ] },
		 { variable     => [ "value_lang",  [ type => "label" ] ] },
		 { variable     => [ "edit",        [ type => "action" ] ] },
	];
}

sub default
{
	my $this   = shift;
        my $reply  = shift;
	my @ret;
	push @ret, { subtitle => 'Select the Language' };

	if(exists($reply->{warning})){
		push @ret, { NOTICE => "$reply->{warning}" };
		push @ret, { lang     => getLanguages("$reply->{lang}") };
		push @ret, { text_se  => "$reply->{text_se}"};
	}else{
		push @ret, { lang     => getLanguages(main::GetSessionValue('lang')) };
		push @ret, { text_se  => ""};
	}
	push @ret, { action   => "enhance" };
	push @ret, { action   => "edit" };
	push @ret, { action   => "search"};
	return \@ret;
}

sub enhance
{
	my $this   = shift;
	my $reply  = shift;
	my $value  = undef;
	my @t      = ( 'table' );
	my $i      = 1;

	my $sel  = $this->{DBH}->prepare("SELECT section,string FROM missedlang WHERE lang='".$reply->{lang}."' AND value=''");
	   $sel->execute;
	while( $value = $sel->fetch() )
	{
	   push @t , { line => [ "$i" , { section => $value->[0] } , { string => $value->[1] }, { value_missedlang => '' } ] } ;
	   $i++;
	}
	return [
		{ table    => \@t },
		{ name     => 'lang' , value => $reply->{lang} , attributes => [ type => 'hidden' ] },
		{ action   => "cancel" },
		{ action   => "apply" }
	];
}

sub edit
{
	my $this   = shift;
	my $reply  = shift;
        my $lang   = $reply->{lang} ? $reply->{lang} : $reply->{line} ;
	my $sect   = $reply->{$lang}->{sections} || 'GLOBAL';
	my $value  = undef;
	my @lines      = ( 'table' );
	my @s      = ();
	my $i      = 1;

	my $sel  = $this->{DBH}->prepare("SELECT distinct(section) FROM lang WHERE lang='$lang'");
		$sel->execute;
	while( $value = $sel->fetch() )
	{
		push @s, $value->[0];
	}
	push @s, '---DEFAULTS---', $sect;

	my $hash = $this->select_value("$lang","$sect");
	foreach my $string (sort keys %{$hash->{$sect}}){
		push @lines , { line => [ "$string" ,
					{ section => $sect },
					{ string => $string },
					{ value_missedlang => $hash->{$sect}->{$string}->{value_missedlang} },
					{ value_lang => $hash->{$sect}->{$string}->{value_lang} },
			]};
	}

	return [
		{ line     => [ $lang , { sections => \@s } , { edit => main::__('edit') } ] },
		{ table    => \@lines },
		{ name     => 'lang', value => "$lang", attributes => [ type => 'hidden' ] },
		{ name     => 'sect', value => "$sect", attributes => [ type => 'hidden' ] },
		{ name     => 'page', value => "edit", attributes => [ type => 'hidden' ] },
		{ action   => "cancel" },
		{ action   => "apply" }
	];
}

sub apply
{
	my $this   = shift;
	my $reply  = shift;
	my $lang   = $reply->{lang};

	foreach my $string (keys %{$reply->{table}}){
		next if ( ! $reply->{table}->{$string}->{value_missedlang} );
		main::AddTranslation($lang,$reply->{table}->{$string}->{section},$reply->{table}->{$string}->{string},$reply->{table}->{$string}->{value_missedlang});
	}

	if( $reply->{page} eq "edit" ){
		$reply->{$lang}->{sections} = "$reply->{sect}";
		$this->edit($reply);
	}elsif($reply->{page} eq "search"){
		$this->search($reply);
	}else{
		$this->enhance($reply);
	}
}

sub search
{
	my $this   = shift;
	my $reply  = shift;
	my @ret;
	my $lang   = $reply->{lang};
	my $text_search = $reply->{text_se} ;


	my $text_length = length $text_search;
	if($text_length < 3){
		$reply->{warning} = main::__('Please enter minimum 3 characters or one word to search!');
		return $this->default($reply);
	}

        my @lines      = ( 'table' );
	my $hash = $this->select_value("$lang","","$text_search");
	foreach my $sect (sort keys %{$hash}){
		foreach my $string (sort keys %{$hash->{$sect}}){
			push @lines , { line => [ "$string" ,
						{ section => $sect },
						{ string => $string },
						{ value_missedlang => $hash->{$sect}->{$string}->{value_missedlang} },
						{ value_lang => $hash->{$sect}->{$string}->{value_lang} },
				]};
		}
	}

	push @ret, { subtitle => 'search' };
	push @ret, { name     => 'text_se', value => "$text_search", attributes => [ type => 'string', style => "width:500px"] };
	push @ret, { table    => \@lines };
	push @ret, { name     => 'lang' , value => $lang , attributes => [ type => 'hidden' ] };
	push @ret, { name     => 'page', value => "search", attributes => [ type => 'hidden' ] };
	push @ret, { rightaction => 'search' };
	push @ret, { rightaction => "apply"};
	push @ret, { rightaction => "cancel" };
	return \@ret;
}

sub select_value
{
	my $this   = shift;
	my $lang   = shift;
	my $sect   = shift;
	my $text_search = shift;
	my %hash;
	my $value  = undef;

	my $cmd_select_lang = "SELECT section,string,value FROM lang WHERE lang='$lang' AND section='$sect'";
	my $cmd_select_missedlang = "SELECT section,string,value FROM missedlang WHERE lang='$lang' AND section='$sect'";

	if($text_search){
		$cmd_select_lang = "SELECT section,string,value FROM lang WHERE lang='$lang' AND (string LIKE '%$text_search%' or value LIKE '%$text_search%')";
		$cmd_select_missedlang = "SELECT section,string,value FROM missedlang WHERE lang='$lang' AND (string LIKE '%$text_search%' or value LIKE '%$text_search%')";
	}

	#select lang table
	my $sel  = $this->{DBH}->prepare("$cmd_select_lang"); $sel->execute;
	while( $value = $sel->fetch() )
	{
		$hash{$value->[0]}->{$value->[1]}->{'value_lang'} = $value->[2];
        }

	#select missedlang table
	$value  = undef;
	$sel  = $this->{DBH}->prepare("$cmd_select_missedlang"); $sel->execute;
	while( $value = $sel->fetch() )
	{
		$hash{$value->[0]}->{$value->[1]}->{'value_missedlang'} = $value->[2];
	}

	return \%hash;
}

1;
