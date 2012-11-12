# Module Portal
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package Portal;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use MIME::Base64;
use Encode qw(encode decode);

use vars qw(@ISA);
@ISA = qw(oss_base);

my $DEFAULT_PAGE = { 
			0 => { NAME => 'Open School Server Administration' ,
		     		URL  => 'cgi-bin/admin.cgi',
		     		LOGO => 'logo_oss.png',
				DESC => 'Verwalten von Klassen, Schülern, Netzwerk, Anwendungen',
				DISABLED => 0
			      },
			1 => { NAME => 'Openexchange' ,
		     		URL  => '/openxchange/',
		     		LOGO => 'logo_ox.png',
				DESC => 'E-Mail, Kalender, Kontakte, Dokumente',
				DISABLED => 1
			      },
			2 => { NAME => 'E-Groupware' ,
		     		URL  => '/egroupware/',
		     		LOGO => 'logo_eg.png',
				DESC => 'E-Mail, Kalender, Kontakte',
				DISABLED => 1
			      },
			3 => { NAME => 'Joomla Content Management' ,
		     		URL  => '/joomla/',
		     		LOGO => 'logo_jo.png',
				DESC => 'Informationen im Internet veröffentlichen',
				DISABLED => 1
			      },
			4 => { NAME => 'Wikipedia' ,
		     		URL  => 'http://de.wikipedia.org',
		     		LOGO => 'logo_wiki.png',
				DESC => 'Die freie Enzyklopädie',
				DISABLED => 0
			      },
			5 => { NAME => 'Moodle E-Learning' ,
		     		URL  => '/moodle/',
		     		LOGO => 'logo_moodle.gif',
				DESC => 'Unterricht online gestalten',
				DISABLED => 1
			      },
			6 => { NAME => 'ClaXss' ,
		     		URL  => '/monitor/',
		     		LOGO => 'logo_clasxx.png',
				DESC => 'Klassen verwalten',
				DISABLED =>1
			      },
			7 => { NAME => 'dict.leo.org' ,
		     		URL  => 'http://dict.leo.org',
		     		LOGO => 'logo_leo.gif',
				DESC => 'Online Wörterbuch',
				DISABLED => 0
			      }
	
		   };

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    if( -e '/srv/www/oss/openxchange' )
    {
    	$DEFAULT_PAGE->{1}->{DISABLED} = 0;	
    }
    if( -e '/srv/www/oss/egroupware' )
    {
    	$DEFAULT_PAGE->{2}->{DISABLED} = 0;	
    }
    if( -e '/srv/www/oss/joomla' )
    {
    	$DEFAULT_PAGE->{3}->{DISABLED} = 0;	
    }
    if( -e '/srv/www/oss/moodle' )
    {
    	$DEFAULT_PAGE->{5}->{DISABLED} = 0;	
    }
    return bless $self, $this;
}

sub interface
{
        return [
                "getCapabilities",
                "default",
		"save",
		"save_all",
		"create_page",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Portal' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { category     => 'System' },
                { order        => 30 },
		{ variable     => [ "number",        [ type => "label" ] ] },
                { variable     => [ "logo",          [ type => "filefield" ] ] },
                { variable     => [ "name",          [ type => "string" ] ] },
                { variable     => [ "description",   [ type => "string" ] ] },
		{ variable     => [ "url",           [ type => "string" ] ] },
		{ variable     => [ "disable",       [ type => "boolean" ] ] },
                { variable     => [ "schoollogo",    [ type => "filefield" ] ] },
		{ variable     => [ "schoolname",    [ type => "string" ] ] },
		{ variable     => [ "snamedisable",  [ type => "boolean" ] ] }
        ];
}

sub default
{
        my $this = shift;
        my $reply =shift;
        my @lines  = ('schools');

#	my @defschools   = $this->get_schools();

        push @lines, { head => [
			{ name => 'number',      attributes => [ label => main::__('#') ] },
                        { name => 'logo',        attributes => [ label => main::__('Logo') ] },
                        { name => 'name',        attributes => [ label => main::__('Name') ] },
                        { name => 'description', attributes => [ label => main::__('Description') ] },
                        { name => 'url',         attributes => [ label => main::__('URL') ] },
			{ name => 'disable',     attributes => [ label => main::__('Disable') ] },
                        { name => 'save',        attributes => [ label => main::__('save') ] },
                        ]
                };


	my $counter = 1;
	for(my $i = 0; $i<8; $i++){
		my $name        = defined $this->get_school_config("SCHOOL_PORTAL_NAME_$i")        ?
					   $this->get_school_config("SCHOOL_PORTAL_NAME_$i")       : encode("utf8", main::__($DEFAULT_PAGE->{$i}->{NAME}));
		my $description = defined $this->get_school_config("SCHOOL_PORTAL_DESCRIPTION_$i") ?
					   $this->get_school_config("SCHOOL_PORTAL_DESCRIPTION_$i"): encode("utf8", main::__($DEFAULT_PAGE->{$i}->{DESC}));
		my $url         = defined $this->get_school_config("SCHOOL_PORTAL_URL_$i")         ?
					   $this->get_school_config("SCHOOL_PORTAL_URL_$i")        : $DEFAULT_PAGE->{$i}->{URL};
		my $disable     = defined $this->get_school_config("SCHOOL_PORTAL_DISABLE_$i")     ?
					   $this->get_school_config("SCHOOL_PORTAL_DISABLE_$i")    : $DEFAULT_PAGE->{$i}->{DISABLED};

		push @lines, { line => [ $i,
			{ number => $counter },
                        { logo => '' },
                        { name => $name },
                        { description => $description },
                        { url => $url },
			{ disable => $disable},
                        { action => 'save'},
                ]};
		$counter++;
	}

	my $descr = '----------leiras------------';
        my $defname = $this->get_school_config("SCHOOL_PORTAL_SN") || '';
        my $snamedisable = $this->get_school_config("SCHOOL_PORTAL_SND") || 0;

	my @school = ( );
#	push @school, { NOTICE => $descr};
	push @school, { schoollogo => '' };
	push @school, { schoolname => $defname };
	push @school, { snamedisable => $snamedisable };
	push @school, { table => \@lines};
	push @school, { action => 'save_all'};
	push @school, { action => 'create_page'};

	return \@school;

}

sub save_all
{
	my $this = shift;
        my $reply = shift;
	my $file;
	$this->delete_school_config("SCHOOL_PORTAL_SN");
	$this->add_school_config('SCHOOL_PORTAL_SN',"$reply->{schoolname}",'This is the portal name','string','yes','Portal');
	$this->delete_school_config("SCHOOL_PORTAL_SND");
	$this->add_school_config('SCHOOL_PORTAL_SND',"$reply->{snamedisable}",'This is the school name disable ','string','yes','Portal');

	if( defined $reply->{schoollogo}->{content} )
        {
                $file   = '/srv/www/oss/img/'.$reply->{schoollogo}->{filename};
                my $tmp = write_tmp_file($reply->{schoollogo}->{content});
                system("/usr/bin/base64 -d $tmp >'$file'; rm $tmp;");
		$this->delete_school_config("SCHOOL_PORTAL_SL");
		$this->add_school_config('SCHOOL_PORTAL_SL',$reply->{schoollogo}->{filename},'This is the path to the portal logo file','string','yes','Portal');
        }

	for(my $i = 0; $i < 8; $i++){
		print $i." az iskola 0 tol 7 ig\n";
		if( defined $reply->{schools}->{$i}->{logo}->{content} )
	        {
	                $file   = '/srv/www/oss/img/'.$reply->{schools}->{$i}->{logo}->{filename};
	                my $tmp = write_tmp_file($reply->{schools}->{$i}->{logo}->{content});
	                system("/usr/bin/base64 -d $tmp >'$file'; rm $tmp;");

	                $this->delete_school_config("SCHOOL_PORTAL_LOGO_$i");
	                $this->add_school_config("SCHOOL_PORTAL_LOGO_$i",$reply->{schools}->{$i}->{logo}->{filename},'This is the the portal name','string','yes','Portal');
	        }

	        $this->delete_school_config("SCHOOL_PORTAL_NAME_$i");
	        $this->add_school_config("SCHOOL_PORTAL_NAME_$i",$reply->{schools}->{$i}->{name},'This is the the portal name','string','yes','Portal');
	        $this->delete_school_config("SCHOOL_PORTAL_DESCRIPTION_$i");
	        $this->add_school_config("SCHOOL_PORTAL_DESCRIPTION_$i",$reply->{schools}->{$i}->{description},'This is the portal description','string','yes','Portal');
	        $this->delete_school_config("SCHOOL_PORTAL_URL_$i");
	        $this->add_school_config("SCHOOL_PORTAL_URL_$i",$reply->{schools}->{$i}->{url},'This is the portal url','string','yes','Portal');
		$this->delete_school_config("SCHOOL_PORTAL_DISABLE_$i");
                $this->add_school_config("SCHOOL_PORTAL_DISABLE_$i",$reply->{schools}->{$i}->{disable},'This is the portal logo disable','string','yes','Portal');


	}

	return $this->default();
}

sub save
{
	my $this = shift;
	my $reply = shift;
	my $file;

	if( defined $reply->{schools}->{$reply->{line}}->{logo}->{content} )
        {
                $file   = '/srv/www/oss/img/'.$reply->{schools}->{$reply->{line}}->{logo}->{filename};
                my $tmp = write_tmp_file($reply->{schools}->{$reply->{line}}->{logo}->{content});
                system("/usr/bin/base64 -d $tmp >'$file'; rm $tmp;");
		
		$this->delete_school_config("SCHOOL_PORTAL_LOGO_$reply->{line}");
		$this->add_school_config("SCHOOL_PORTAL_LOGO_$reply->{line}",$reply->{schools}->{$reply->{line}}->{logo}->{filename},'This is the the portal name','string','yes','Portal');
        }

	$this->delete_school_config("SCHOOL_PORTAL_NAME_$reply->{line}");
	$this->add_school_config("SCHOOL_PORTAL_NAME_$reply->{line}","$reply->{schools}->{$reply->{line}}->{name}",'This is the portal name','string','yes','Portal');
	$this->delete_school_config("SCHOOL_PORTAL_DESCRIPTION_$reply->{line}");
	$this->add_school_config("SCHOOL_PORTAL_DESCRIPTION_$reply->{line}","$reply->{schools}->{$reply->{line}}->{description}",'This is the portal description','string','yes','Portal');
	$this->delete_school_config("SCHOOL_PORTAL_URL_$reply->{line}");
	$this->add_school_config("SCHOOL_PORTAL_URL_$reply->{line}","$reply->{schools}->{$reply->{line}}->{url}",'This is the portal url','string','yes','Portal');
	$this->delete_school_config("SCHOOL_PORTAL_DISABLE_$reply->{line}");
        $this->add_school_config("SCHOOL_PORTAL_DISABLE_$reply->{line}","$reply->{schools}->{$reply->{line}}->{disable}",'This is the portal logo disable','string','yes','Portal');

	return $this->default();
}

sub create_page
{
	my $this = shift;
	my $reply =shift;

	my $plogo = $this->get_school_config("SCHOOL_PORTAL_SL")        || 'logo_oss.png';
	my $name = $this->get_school_config("SCHOOL_NAME");
	my $defname = $this->get_school_config("SCHOOL_PORTAL_SN")      || '';
	my $defnameflag = $this->get_school_config("SCHOOL_PORTAL_SND") || 0;

	my $sed_cmd = " -e 's#%LOGO%#$plogo#'";
	if ( $defnameflag and ($plogo eq "logo_white.png")){
		$sed_cmd .= " -e 's#%HEADER_STYLE%#style='height:0px'#'";
	}
	if ( $defnameflag ) {
		$sed_cmd .= " -e 's#%SDESCR%##' -e 's#%SNAME%##' -e 's#%HEADER_STYLE%#style='height:120px'#'";
	}elsif( !$defnameflag and !$defname ){
		$sed_cmd .= " -e 's#%SDESCR%##' -e 's#%SNAME%#$name#' -e 's#%HEADER_STYLE%#style='height:120px'#'";
	}else{
		$sed_cmd .= " -e 's#%SDESCR%#$defname#' -e 's#%SNAME%##' -e 's#%HEADER_STYLE%#style='height:120px'#'";
	}


	for(my $i = 0; $i<8; $i++){
		my $name        = defined $this->get_school_config("SCHOOL_PORTAL_NAME_$i")        ?
					   $this->get_school_config("SCHOOL_PORTAL_NAME_$i")       : main::__($DEFAULT_PAGE->{$i}->{NAME}) ;
		my $description = defined $this->get_school_config("SCHOOL_PORTAL_DESCRIPTION_$i") ?
					   $this->get_school_config("SCHOOL_PORTAL_DESCRIPTION_$i"): main::__($DEFAULT_PAGE->{$i}->{DESC});
		my $url         = defined $this->get_school_config("SCHOOL_PORTAL_URL_$i")         ?
					   $this->get_school_config("SCHOOL_PORTAL_URL_$i")        : $DEFAULT_PAGE->{$i}->{URL};
		my $disable     = defined $this->get_school_config("SCHOOL_PORTAL_DISABLE_$i")     ?
					   $this->get_school_config("SCHOOL_PORTAL_DISABLE_$i")        : $DEFAULT_PAGE->{$i}->{DISABLED};
		my $logo        = defined $this->get_school_config("SCHOOL_PORTAL_LOGO_$i")        ?
	 				   $this->get_school_config("SCHOOL_PORTAL_LOGO_$i")	   : $DEFAULT_PAGE->{$i}->{LOGO};
		my $j=$i+1;
		if (!$disable) {
			$sed_cmd .= " -e 's#%LOGO$j%#$logo#' -e 's#%NAME$j%#$name#' -e 's#%DESCRIPTION$j%#$description#' -e 's#%URL$j%#$url#'";
		}else{
		 	$sed_cmd .= " -e 's#%LOGO$j%#logo_white.png#' -e 's#%NAME$j%##' -e 's#%DESCRIPTION$j%##' -e 's#%URL$j%##'";
		}
	}

#	print $sed_cmd;
	system("sed $sed_cmd < /srv/www/oss/index.tpl > /srv/www/oss/index.html");

	return $this->default();
}


1;

