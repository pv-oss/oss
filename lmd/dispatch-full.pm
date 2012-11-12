#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2007 Peter Varkoly <peter@varkoly.de>, Fürth.  All rights reserved.
#
# $Id: lmd.pl pv Exp $
#
#
=head1 NAME

 dispatch.pl
 
=head1 PREFACE

 SUSE Linux System Managemant Daemon HTML CGI Tester Program

=head1 DESCRIPTION

This Program sends som test request to lmd.

=cut

package dispatch;
use strict;
use CGI qw/:standard/;
use XML::Parser;
use XML::Writer;
use Data::Dumper;
use IO::Socket::UNIX;
use IO::Socket::SSL;
use Encode;
use MIME::Base64;

my $DEBUG	= 1;
my $DEBUGFILE	= "/tmp/log.dispatch";
my $PORT        = "1967";
my $ADDRESS     = "localhost";
my $SOCKET      = "/var/run/lmd.sock";
my $APPNAME     = "Linux System Managemant";
my $SESSIONID   = undef;
my $ACTION      = undef;
my $APPLICATION = undef;
my $CATEGORY    = undef;
my $VALUE       = undef;
my $VARIABLE    = undef;
my $V_LABEL     = undef;
my $V_TYPE      = undef;
my @V_ATTR      = ();
my %LABELS      = ();
my @VALUES      = ();
my @DEFAULTS    = ();
my @MEMBERS	= ();
my @NOMEMBERS	= ();
my %LMEMBERS	= ();
my %LNOMEMBERS	= ();
my $VALUE_LABEL = undef;
my $TABLE       = "";
my $CONTENT     = "";
my $SUBTITLE    = "";
my $TITLE       = "";
my $ACTIONS     = undef;
my $RIGHTACTIONS= undef;
my $MENU	= {};
my $LMENU	= {};
my $IS_TABLE    = 0;
my $IS_LINE     = 0;
my $IS_LIST     = 0;
my $IS_DEFAULT  = 0;
my $IS_FIRST_LINE= 0;
my $IS_MEMBER   = 0;
my $IS_NOMEMBER = 0;
my $TABLE_NAME  = '';
my $LINE_NAME   = '';
my $LANG        = '';
my $HEADER      = '';
my $HTML        = '';
my @MONTHS      = ( '01','02','03','04','05','06','08','09','10','11','12' );
my @DAYS        = ( '01','02','03','04','05','06','08','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31' );
my @HOURS       = ( '00', '01','02','03','04','05','06','08','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23' );
my @MINUTES     = ( '00', '01','02','03','04','05','06','08','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','38','39','40','41','42','43','44','45','46','47','48','49','50','51','52','53','54','55','56','57','58','59' );
my $SUB_MENU_LEFT = 1;

sub new
{
    my ($this, $cgi, $session) = @_;
    my $class         = ref($this) || $this;
    my $self          = {};
    $self->{"CGI"}    = $cgi;
    bless $self, $this;
    return $self;
}

sub display
{

    my $this   = shift;
    my $params = $this->{"CGI"}->Vars;
    
    open DEBUGH,">>$DEBUGFILE" if $DEBUG;
    Debug("display called\n");
    print DEBUGH Dumper($params) if $DEBUG;

    $ACTION       = $params->{'ACTION'};
    $APPLICATION  = $params->{'APPLICATION'};

    if( (!defined $ACTION && !defined $APPLICATION) || $ACTION eq 'LOGOUT')
    {
    	$this->login();
    }
    elsif( $ACTION eq 'LOGIN' )
    {
        $this->checkLogin();
    }
    else
    {
    	$this->getMenu();
    	$this->printMenu();
    }
    close DEBUGH if $DEBUG;

}

sub login
{
    my $this   = shift;
    my $params = $this->{"CGI"}->Vars;
    Debug("login called\n");

    my    $CGI = new CGI;
    print $CGI->header(-charset=>'UTF-8');
	  $CGI->autoEscape(1);
    print $CGI->start_html(-title => $APPNAME, -align=>"center", -style =>{'src'=>'/lmd.css'} );
    print '<center>';
    print $CGI->start_form(-action=>'/cgi-bin/dispatch.pl', -target=>'_top', -name=>'login_form');
    print     $CGI->start_table({-border=>0, -cellspacing=>0, -cellpadding=>"10"});
    print         $CGI->start_Tr();
    print             $CGI->start_td();
    print		  "Username : ";
    print             $CGI->end_td();
    print             $CGI->start_td();
    print                 $CGI->textfield( -name           => 'username',
                                           -maxlength      => 35,
                                           -size           => 30);
    print                 "<script>document.login_form.username.focus()</script>";
    print             $CGI->end_td();
    print         $CGI->end_Tr();
    print         $CGI->start_Tr();
    print             $CGI->start_td();
    print		  "Password : ";
    print             $CGI->end_td();
    print             $CGI->start_td();
    print                 $CGI->password_field( -name           => 'userpassword',
                                                -maxlength      => 35,
                                                -size           => 30);
    print             $CGI->end_td();
    print         $CGI->end_Tr();
    print         $CGI->start_Tr();
    print             $CGI->start_td();
    print                 "&nbsp;";
    print             $CGI->end_td();
    print             $CGI->start_td({-valign=>"middle"});
    print                 $CGI->submit(-class=>"button",-name=>'login', -value=>"Login");
#    print                 $CGI->hidden(-name=>'APPLICATION', -value=>"WEB");
    print             $CGI->end_td();
    print         $CGI->end_Tr();
    print     $CGI->end_table();
    print     "\n";
    print     '<input type="hidden" name="ACTION" value="LOGIN" >';
# Ich erschieße mich aber das tut nicht
#    print     $CGI->hidden(-name=>'ACTION',  -value=>'LOGIN');
    print     "\n";
    print $CGI->end_form();
    print '</center>';
    print $CGI->end_html();

}

sub checkLogin
{

    my $this   = shift;
    my $params = $this->{"CGI"}->Vars;
    Debug("checkLogin called\n");

    my $REQUEST = '<request name="login">
<username>'.$params->{'username'}.'</username>
<userpassword>'.$params->{'userpassword'}.'</userpassword>
<ip>'.$this->{CGI}->remote_addr.'</ip>
</request>' ;
    sendRequest($REQUEST);
    Debug("SESSSIONID $SESSIONID\n");
    $this->getMenu();
    $this->printMenu();
}

sub getMenu
{
    my $this   = shift;
    my $params = $this->{"CGI"}->Vars;
    if( defined $params->{'SESSIONID'} )
    {
        $SESSIONID  = $params->{'SESSIONID'};
    }
    Debug("getMenu called\n");
    sendRequest('<request name="getMenu" sessionID="'.$SESSIONID.'" ip="'.$this->{CGI}->remote_addr.'"/>');
}

sub printMenu
{
    my $this    = shift;
    my $params  = $this->{"CGI"}->Vars;
    my $sect    = $params->{'CATEGORY'};
    my $appl    = $params->{'APPLICATION'} || '';
    my $act     = $params->{'ACTION'}      || 'default';
    my $line	= '';
    my $table   = '';
    if( $params->{'SESSIONID'} )
    {
        $SESSIONID  = $params->{'SESSIONID'};
    }	
    my $request = "";
    my $CGI     = new CGI;
    Debug("printMenu called\n");

    Debug("APP: $appl\nACT: $act\n");
    if( $appl ne '' )
    {
        foreach my $key ( keys %{$params} )
	{
		my @action = split /\+/, $key; 
		if( $action[0] eq "action" )
		{
			$act    = $action[1];
			$line   = $action[2] || '';
			$table  = $action[3] || '';
		}
	}

        Debug("MY --- $request\n");
        my $writer = new XML::Writer(OUTPUT => \$request, ENCODING => "UTF-8", DATA_MODE => 1);
        $writer->startTag("request", name=>$act, application=>$appl, line=>$line, table=>$table, sessionID=>$SESSIONID, ip=>$this->{CGI}->remote_addr(), result=> "0" );

        foreach my $key ( keys %{$params} )
	{
		if( $key =~ /action\+.*/ )
		{
			next;
		}
		elsif( $key =~ /filefield\+(.*)/ )
		{
			my $filename  = $this->{CGI}->upload($key);
			next if ( ! defined $filename );
			my ($buffer, $par, $bytesread );
			while ($bytesread=read($filename,$buffer,1024))
			{
				$par .= $buffer;
			}
			$par = encode_base64($par);
			my @var   = split /\+/, $1; 
			my $name  = $var[0];
			my $line  = $var[1] || '';
			my $table = $var[2] || '';
			$writer->dataElement($name, $par,  line=>$line, table=>$table);
		}
		else
		{
			my @pars  = $this->{CGI}->param($key);
			my @var   = split /\+/, $key; 
			my $name  = $var[0];
			my $line  = $var[1] || '';
			my $table = $var[2] || '';

			if( scalar @pars > 1 )
			{
				$writer->dataElement($name,join("\n",@pars), line=>$line, table=>$table );
				#$writer->startTag($name,line=>$line, table=>$table);
				#foreach(@pars) {
				#	$writer->dataElement('VALUE',$_, line=>$line, table=>$table, var=>$name );
				#}
				#$writer->endTag($name);
			}
			else
			{
				$writer->dataElement($name,$params->{$key},  line=>$line, table=>$table);
			}
		}
	}
	$writer->endTag("request");
    	$writer->end();
	Debug($request);
        sendRequest($request);
    }
    print DEBUGH "MENU:".Dumper($MENU) if $DEBUG;

    my $colspan = $RIGHTACTIONS ? 3: 2 ;
    print $CGI->header(-charset=>'utf-8');
    print $CGI->start_html(-title=>$APPNAME, -align=>"center", -style =>{'src'=>'/lmd.css'} );
    print '<center>';
    print $CGI->start_multipart_form(-action=>'/cgi-bin/dispatch.pl', -target=>'_top', -name=>'menu');
    print     $CGI->start_table({-class=>'AdminBorder'});
    print         $CGI->start_Tr();
    print             $CGI->start_td({-class=>'AdminHead',-colspan=>$colspan});
    print		  $CGI->a({-class=>'HeadMenuItem',-href =>'/cgi-bin/dispatch.pl?ACTION=LOGOUT&SESSIONID='.$SESSIONID},menuItem('logout'));
    print             $CGI->end_td();
    print         $CGI->end_Tr();
    my $main_menu = $CGI->start_table({-class=>'MainMenu'});
    my $sub_menu  = $CGI->start_table({-class=>'SubMenu'});
    foreach my $section ( keys %{$MENU} )
    {
	if( $sect eq $section )
	{ # Selected main menu item
		$main_menu .= $CGI->Tr($CGI->td({-class=>'ActivMainMenuItem'},
				  $CGI->a({-href =>'/cgi-bin/dispatch.pl?CATEGORY='.$section.'&ACTION=SHOW_SUBMENU&SESSIONID='.$SESSIONID},menuItem($section))
			      ));
		if( $SUB_MENU_LEFT )
		{
			foreach my $application ( @{$MENU->{$section}})
			{
				if( $application eq $appl )
				{
				     $main_menu .= $CGI->Tr({}, $CGI->td({-class=>'ActivSubMenuItem'},
					  $CGI->a({-href =>'/cgi-bin/dispatch.pl?CATEGORY='.$section.'&APPLICATION='.$application.'&ACTION=default&SESSIONID='.$SESSIONID},menuItem($section,$application))
				      ));
				}
				else
				{
				     $main_menu .=  $CGI->Tr({}, $CGI->td({-class=>'SubMenuItem'},
					  $CGI->a({-href =>'/cgi-bin/dispatch.pl?CATEGORY='.$section.'&APPLICATION='.$application.'&ACTION=default&SESSIONID='.$SESSIONID},menuItem($section,$application))
				      ));
				}
			}
		}
		else
		{
			$sub_menu .= $CGI->start_Tr({-class=>'SubMenuHeader'});
			foreach my $application ( @{$MENU->{$section}})
			{
				if( $application eq $appl )
				{
				     $sub_menu .= $CGI->td({-class=>'ActivSubMenuItem'},
					  $CGI->a({-href =>'/cgi-bin/dispatch.pl?CATEGORY='.$section.'&APPLICATION='.$application.'&ACTION=default&SESSIONID='.$SESSIONID},menuItem($section,$application)
				      ));
				}
				else
				{
				     $sub_menu .= $CGI->td({-class=>'SubMenuItem'},
					  $CGI->a({-href =>'/cgi-bin/dispatch.pl?CATEGORY='.$section.'&APPLICATION='.$application.'&ACTION=default&SESSIONID='.$SESSIONID},menuItem($section,$application)
				      ));
				}
			}
			$sub_menu .= $CGI->end_Tr();
		}
	}
	else
	{ #Normal main menu item
		$main_menu .= $CGI->Tr($CGI->td({-class=>'MainMenuItem'},
				  $CGI->a({-href =>'/cgi-bin/dispatch.pl?CATEGORY='.$section.'&ACTION=SHOW_SUBMENU&SESSIONID='.$SESSIONID},menuItem($section))
			      ));
	}
    }
#    $main_menu .= $CGI->Tr($CGI->td({-height=>'200'},'&nbsp;'));
    $main_menu .= $CGI->end_table();
    $sub_menu  .= $CGI->end_table();

    if( ! $SUB_MENU_LEFT )
    {
	    print         $CGI->start_Tr();
	    print             $CGI->td({-class=>'AdminCorner'},'&nbsp;');
	    print             $CGI->td({-class=>'SubMenuContainer'},$sub_menu);
	    print         $CGI->end_Tr();
    }  
Debug("CONTENT--\n".$CONTENT);
    print         $CGI->start_Tr();
    print             $CGI->td({-class=>'MainMenuContent', -align=>"left", -valign=>"top"},$main_menu);
    print             $CGI->td({-class=>'MainContent',     -align=>"left", -valign=>"top"},
				$CGI->start_table({-class=>'ContenContainer', -align=>"left", -valign=>"top" }).
					$CGI->Tr($CGI->td({class=>'ApplicationTitle',colspan=>$colspan},$TITLE)).
					$CGI->Tr($CGI->td({class=>'ApplicationSubTitle',colspan=>$colspan},$SUBTITLE)).
					$CONTENT.
					$CGI->Tr($CGI->td({class=>'Actions',colspan=>2},$ACTIONS)).
				$CGI->end_table());
    if( $RIGHTACTIONS )
    {
    	print             $CGI->td({-class=>'MainContent',     -align=>"left", -valign=>"top"},$RIGHTACTIONS );
    }
    print         $CGI->end_Tr();
    print     $CGI->end_table();
    print     $CGI->hidden( -name=>'APPLICATION',-value=>$appl);
    print     $CGI->hidden( -name=>'CATEGORY',-value=>$sect);
    print     $CGI->hidden( -name=>'SESSIONID',-value=>$SESSIONID);
    print $CGI->end_form();
    print '</center>';
    print $CGI->end_html();

    $ACTIONS = $CONTENT='';
     
}

sub menuItem
{
    my $section       = shift;
    my $application   = shift;

    if( $application )
    {
    	return $LMENU->{$section}->{$application} ? $LMENU->{$section}->{$application} : $application ;
        #return img({-name=>$application.'.png', -src=>'/images/'.$application.'logout.png', -class=>$class, alt=>"$application"});
    }
    else
    {
    	return $LMENU->{$section}->{LABEL} ? $LMENU->{$section}->{LABEL} : $section ;
        #return img({-name=>$section.'.png', -src=>'/images/'.$section.'logout.png', -class=>$class, alt=>"$section"});
    }

}

sub sendRequest
{
    my $REQUEST = shift;
    my $socket  = getSocket();
    $REQUEST = encode_base64($REQUEST);
    my $reply   = '';

    my  $package_size = bytes::length $REQUEST;
    $package_size = pack("l", $package_size);

    syswrite $socket, $package_size, 4;
    print $socket $REQUEST;

    Debug($REQUEST);

    #reading package length from client
    sysread $socket, $package_size, 4;
    $package_size = unpack("l", $package_size);
    Debug("$package_size byte package is expected from client.\n");

    $socket->read($reply, $package_size);
    $reply = decode_base64($reply);
    Debug("reply got from client:\n\n".$reply);

    my $p1 = new XML::Parser(Style => 'Stream', ProtocolEncoding => 'UTF-8');
    Debug( $reply );
    #my $r = encode("utf8",$reply);
    $p1->parse($reply);
    close $socket;
}

sub getSocket
{
        my $this   = shift;
	my $socket = undef;
	#start the socket
	if( $ADDRESS eq "unix" )
	{
	    $socket = IO::Socket::UNIX->new(
		Type           => SOCK_STREAM,
		Peer           => $SOCKET
	    );
	}
	else
	{   
	    $socket = IO::Socket::SSL->new(
		PeerAddr       => $ADDRESS,
		PeerPort       => $PORT,
		Proto          => 'tcp',
		Type           => SOCK_STREAM
	    );
	}
	if( defined $socket )
	{
	    return $socket;
	}
	else
	{
    		my $CGI         = new CGI;
		print $CGI->header(-charset=>'UTF-8');
		      $CGI->autoEscape(1);
		print $CGI->start_html(-title => $APPNAME, -align=>"center", -style =>{'src'=>'/lmd.css'} );
		print '<center>';
		print $CGI->h1("OSS Management Does Not Work. Please Contact the System Administrtor!");
		print $CGI->end_html();
		exit 0;
	}
}

#XML Handling
sub StartTag
{
    my ( $v1, $v2 ) = @_;
    if( $v2 eq 'reply' )
    {
        if( defined $_{name} )
        {
            $ACTION = $_{name};
        }
        if( defined $_{sessionID} )
        {
            $SESSIONID = $_{sessionID};
        }
    }
    elsif( $ACTION eq 'getMenu' && $v2 eq "category" )
    {
        $CATEGORY=$_{'name'};
	$LMENU->{$CATEGORY}->{LABEL} = $_{'label'};
    }
    elsif( $ACTION eq 'getMenu' && $v2 eq 'application' )
    {
        push @{$MENU->{$CATEGORY}}, $_{'name'};
	$LMENU->{$CATEGORY}->{$VALUE} = $_{'label'};
    }
    elsif( $v2 eq 'line' )
    {
	$LINE_NAME=$_{'name'};
        $IS_LINE = 1;
    }
    elsif( $v2 eq 'table' )
    {
	$TABLE_NAME=$_{'name'};
        $IS_TABLE = 1;
        $IS_FIRST_LINE = 1;
    }
    elsif( $v2 eq 'MEMBER' )
    {
        $IS_MEMBER = 1;
	$VALUE_LABEL = $_{'label'};
    }
    elsif( $v2 eq 'NOMEMBER' )
    {
        $IS_NOMEMBER = 1;
	$VALUE_LABEL = $_{'label'};
    }
    elsif( $v2 eq 'DEFAULT' )
    {
	$IS_DEFAULT = 1;
    }
    elsif( $v2 eq 'VALUE' )
    {
	$IS_LIST = 1;
	if( defined $_{'label'} && $_{'label'} ne "" )
	{
	    $VALUE_LABEL = $_{'label'};
	}    
    }
    else
    {
        $VARIABLE=$v2;
	if( $VARIABLE =~ /action$/ )
	{
		$V_LABEL=$_{'label'} || undef;
		$V_TYPE=$_{'type'}   || 'action';
	}
	else
	{
		$V_LABEL=$_{'label'} || $VARIABLE;
		$V_TYPE=$_{'type'}   || 'string';
	}
	if( $V_TYPE eq 'changemember' )
	{
	   #TODO member no member label
	}
	@V_ATTR=();
	foreach my $i ( keys %_ )
	{ #Handling of other html attributes
	    next if( $i =~ /^label|type$/ );
	    push @V_ATTR, "-$i",$_{$i};
	}
	print DEBUGH "VARIABLE: $VARIABLE;  LABEL: $V_LABEL; V_TYPE: $V_TYPE\n" if($DEBUG);
	print DEBUGH "V_ATTR".Dumper(@V_ATTR)."\n" if($DEBUG);
    }
}

sub Text
{
   print DEBUGH "TEXT\n" if($DEBUG);
   if( $IS_MEMBER )
   {
	push @MEMBERS, $_;
	$LMEMBERS{$_} = $VALUE_LABEL;
   }
   elsif( $IS_NOMEMBER )
   {
	push @NOMEMBERS, $_;
	$LNOMEMBERS{$_} = $VALUE_LABEL;
   }
   elsif( $IS_DEFAULT )
   {
	print DEBUGH "   list default: $_ \n" if($DEBUG);
	push @DEFAULTS, $_;
   }
   elsif( $IS_LIST )
   {
	print DEBUGH "   list value: $_ \n" if($DEBUG);
   	if( defined $VALUE_LABEL )
	{
	    $LABELS{$_} = $VALUE_LABEL;
	}
	push @VALUES, $_;
   }
   else
   {
     print DEBUGH "   value: $_ \n" if($DEBUG);
     $VALUE = $_;
   }
}

sub EndTag
{
    my ( $v1, $v2 ) = @_;
    my $CGI         = new CGI;

    Debug("EndTag VARIABLE $VARIABLE VALUE $VALUE\n########\n");
    if( $v2 eq 'title' )
    {
	$TITLE=$VALUE;
	$VALUE=undef;
    }
    elsif( $v2 eq 'subtitle' )
    {
	$SUBTITLE=$VALUE;
	$VALUE=undef;
    }
    elsif( $v2 eq 'line' )
    {
	if( $IS_TABLE )
	{
	   $TABLE   .= $CGI->Tr({-class=>"ContentTableLine"},$HTML);
	}
	else
	{
	   $CONTENT .= $CGI->Tr($CGI->td({-class=>"ContentLine",-colspan=>2},$CGI->start_table({-class=>"ContentLineTable",-border=>0}),$CGI->Tr($HTML).$CGI->end_table()));
	}
        $IS_LINE       = 0;
        $IS_FIRST_LINE = 0;
	$LINE_NAME     = "";
	$HTML          = "";
    }
    elsif( $v2 eq 'table' )
    {
	$CONTENT .= $CGI->Tr($CGI->td({-colspan=>2}, $CGI->start_table({-class=>"ContentTable",-border=>1}).$CGI->Tr($HEADER).$TABLE.$CGI->end_table()))."\n";
        $IS_TABLE = 0;
        $TABLE    = '';
	$TABLE_NAME = '';
	$HEADER     = '';
    }
    elsif( $v2 =~ /MEMBER|VALUE|DEFAULT/ )
    {
	Debug( "LISTVALUE: $VARIABLE => $VALUE_LABEL");
	$VALUE_LABEL=undef;
        $IS_DEFAULT = $IS_LIST = $IS_MEMBER = $IS_NOMEMBER = 0;
    }
    elsif( $VARIABLE )
    {
	if( $IS_LINE )
	{
	    $VARIABLE = $VARIABLE.'+'.$LINE_NAME;
	    if( $IS_TABLE )
	    {
	        $VARIABLE = $VARIABLE.'+'.$TABLE_NAME;
	    }
	}
	printVariable();
        if( !$IS_LINE )
	{
	   $CONTENT .= $CGI->Tr($HTML);
	   $HTML="";
	}
        $VARIABLE = $VALUE = $V_LABEL = $V_TYPE = undef;
	@DEFAULTS = @VALUES = @MEMBERS = @NOMEMBERS = %LABELS = %LMEMBERS = %LNOMEMBERS = ();
    }
}

sub printVariable
{
    my $CGI         = new CGI;

    if( $VARIABLE eq 'action' ) 
    {
       if( !$V_LABEL )
       {
       	  $V_LABEL = $VALUE;
       }
       $ACTIONS .= $CGI->submit(-class=>"BottomButton",-name=>'action+'.$VALUE, -value=>"$V_LABEL");
    }
    elsif( $VARIABLE eq 'rightaction' )
    {
       if( !$V_LABEL )
       {
       	  $V_LABEL = $VALUE;
       }
       $RIGHTACTIONS .= $CGI->submit(-class=>"RightButton",-name=>'action+'.$VALUE, -value=>"$V_LABEL").$CGI->br();
    }
    elsif($VARIABLE eq 'ERROR')
    {
    	$HTML .= $CGI->td({-class=>'ERRORMesage', -colspan=>2 },"<br><pre>$VALUE</pre><br>");
    }
    elsif($VARIABLE eq 'NOTICE')
    {
    	$HTML .= $CGI->td({-class=>'Notice', -colspan=>2 },"<br><pre>$VALUE</pre><br>");
    }
    elsif($VARIABLE eq 'label')
    {
    	$HTML .= $CGI->td({-class=>'Label', -colspan=>2 },$VALUE);
    }
    elsif( $V_TYPE eq 'hidden' )
    {
         $HTML .= $CGI->hidden( -name=>$VARIABLE,-value=>$VALUE);
    }
    else
    {
	if( $IS_FIRST_LINE )
	{
	    $HEADER .= $CGI->th({-class=>'ContentLabel'},$V_LABEL);
	}
	if( ! $IS_TABLE && $V_TYPE ne 'filter' && $V_TYPE ne 'changemember')
	{
	    $HTML .= $CGI->td({-class=>'ContentLabel'},$V_LABEL);
	}
        if( $V_TYPE eq 'action' ) 
        {
           if( !$V_LABEL )
           {
           	  $V_LABEL = $VALUE;
           }
           if( $IS_TABLE )
           {
               $HTML .= $CGI->td({},$CGI->submit(-class=>"CentreButtom",-name=>'action+'.$VALUE.'+'.$LINE_NAME.'+'.$TABLE_NAME, -value=>"$V_LABEL"));
           }
           elsif( $IS_LINE )
           {
               $HTML .= $CGI->td({},$CGI->submit(-class=>"CentreButtom",-name=>'action+'.$VALUE.'+'.$LINE_NAME, -value=>"$V_LABEL"));
           }
	}
	elsif( $V_TYPE eq 'checkbox' )
	{
		$HTML .= $CGI->td({-class=>'ContentValue'},'<input type="checkbox" name="'.$VARIABLE.'" value="'.$VALUE.'">');
	}
	elsif( $V_TYPE eq 'boolean' )
	{
	    if( $VALUE )
	    {
		$HTML .= $CGI->td({-class=>'ContentValue'},'<input type="checkbox" name="'.$VARIABLE.'" checked>');
	    }
	    else
	    {
		$HTML .= $CGI->td({-class=>'ContentValue'},'<input type="checkbox" name="'.$VARIABLE.'">');
	    }
	}
	elsif( $V_TYPE eq 'text' )
	{
	    #$HTML .= $CGI->td({class=>'TextAreaContentValue'},$CGI->textarea( -name=>$VARIABLE, -value=>$VALUE,  -wrap=>"off", -cols=>75, -rows=>25 ));
	    my $rows = 25; my $cols = 75;
	    my $i    = 0;
	    my $atts = \@V_ATTR;
	    while ($atts->[$i]) {
	       my $n = $atts->[$i++];
	       my $v = $atts->[$i++];
	       $rows = $v if( $n eq '-rows' );
	       $cols = $v if( $n eq '-cols' );
	    }
	    $HTML .= $CGI->td({-class=>'TextAreaContentValue'},'<textarea name="'.$VARIABLE.'"  rows="'.$rows.'" cols="'.$cols.'" wrap="off">'.$VALUE.'</textarea>');
	}
	elsif( $V_TYPE eq 'date' )
	{
            $VALUE =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;
	    if( $LANG eq 'HU' )
	    {
                $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->textfield(-name=>'YEAR-'.$VARIABLE,  -default=>$1, -size=>4, -maxlength=>4 ).
                                                          '-'.
                                                          $CGI->popup_menu(-name=>'MONTH-'.$VARIABLE,-values=>\@MONTHS,-default=>$2).
                                                          '-'.
                                                          $CGI->popup_menu(-name=>'DAY-'.$VARIABLE,-values=>\@DAYS,-default=>$3));
	    }  
	    elsif( $LANG eq 'US' )
	    {
                $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->popup_menu(-name=>'MONTH-'.$VARIABLE,-values=>\@MONTHS,-default=>$2).
                                                          '/'.
                                                          $CGI->popup_menu(-name=>'DAY-'.$VARIABLE,-values=>\@DAYS,-default=>$3).
							  '/'.
							  $CGI->textfield(-name=>'YEAR-'.$VARIABLE,  -default=>$1, -size=>4, -maxlength=>4 )
                                                          );
	    }  
	    else
	    {
                $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->popup_menu(-name=>'DAY-'.$VARIABLE,  -values=>\@DAYS,  -default=>$3).
                                                          '-'.
                                                          $CGI->popup_menu(-name=>'MONTH-'.$VARIABLE,-values=>\@MONTHS,-default=>$2).
                                                          '-'.
                                                          $CGI->textfield(-name=>'YEAR-'.$VARIABLE, -default=>$1, -size=>4, -maxlength=>4 ));
	    }  

	}
	elsif( $V_TYPE eq 'time' )
	{
	    $VALUE =~ /(\d\d):(\d\d)/;
	    $HTML .= $CGI->td({-class=>'ContentValue', -nowrap=>"1"},$CGI->popup_menu(-name=>'HOUR-'.$VARIABLE,  -values=>\@HOURS,  -default=>$1).
						      ':'.
						      $CGI->popup_menu(-name=>'MINUTE-'.$VARIABLE,-values=>\@MINUTES,-default=>$2));
	}
	elsif( $V_TYPE eq 'label' )
	{
	    $HTML .= $CGI->td({-class=>'ContentValue'},$VALUE);
	
	}
	elsif( $V_TYPE eq 'password' )
	{
	    #$HTML .= $CGI->td({class=>'ContentValue'},'<input type="text" name="'.$VARIABLE.' value='.$VALUE.'>' );
	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->password_field( -name=>$VARIABLE, -default=>$VALUE));
	
	}
#	elsif( $V_TYPE eq 'popup' )
#	{
#	    my @ATTRS = ( "-name", $VARIABLE, "-values", \@VALUES, "-default", $DEFAULTS[0]);
#	    push @ATTRS, @V_ATTR;
#	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->popup_menu( @ATTRS ));
#	
#	}
	elsif( $V_TYPE eq 'popup' )
	{
	    my @ATTRS = ( "-name", $VARIABLE, "-values", \@VALUES, "-labels", \%LABELS, "-default", $DEFAULTS[0]);
	    push @ATTRS, @V_ATTR;
	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->popup_menu( @ATTRS ));
	
	}
#	elsif( $V_TYPE eq 'list' )
#	{
#	    my @ATTRS = ( "-name", $VARIABLE, "-values", \@VALUES, "-defaults", \@DEFAULTS);
#	    push @ATTRS, @V_ATTR;
#	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->scrolling_list( @ATTRS ));
#	
#	}
	elsif( $V_TYPE eq 'list' )
	{
	    my @ATTRS = ( "-name", $VARIABLE, "-values", \@VALUES, "-labels", \%LABELS, "-defaults", \@DEFAULTS);
	    push @ATTRS, @V_ATTR;
	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->scrolling_list( @ATTRS ));
	}
	elsif( $V_TYPE eq 'filter' )
	{
	    my @ATTRS = ( "-name", $VARIABLE, "-values", \@VALUES, "-labels", \%LABELS);
	    push @ATTRS, @V_ATTR;
	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->scrolling_list( @ATTRS ));
	}
	elsif( $V_TYPE eq 'changemember' )
	{
	    my @ATTRS = ( "-name", $VARIABLE.'-member', "-values", \@MEMBERS, "-labels", \%LMEMBERS);
	    push @ATTRS, @V_ATTR;
	    $HTML .= $CGI->start_td({-class=>'ContentValue',-colspan=>2}).$CGI->scrolling_list( @ATTRS );
	    @ATTRS = ( "-name", $VARIABLE.'-nomember', "-values", \@NOMEMBERS, "-labels", \%LNOMEMBERS);
	    push @ATTRS, @V_ATTR;
	    $HTML .= $CGI->scrolling_list( @ATTRS ).$CGI->end_td();
	}
	elsif( $V_TYPE eq 'filefield' )
	{
	    my @ATTRS = ( "-name", 'filefield+'.$VARIABLE, "-default", $VALUE);
	    push @ATTRS, @V_ATTR;
	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->filefield( @ATTRS ));
	}
	else
	{
	    if( ! defined $V_LABEL )
	    {
	    	$HTML .= $CGI->td({-class=>'ContentLabel'},$VARIABLE);
	    }
	    my @ATTRS = ( "-name", $VARIABLE, "-default", $VALUE);
	    push @ATTRS, @V_ATTR;
	    $HTML .= $CGI->td({-class=>'ContentValue'},$CGI->textfield( @ATTRS ));
	}
    }
    $HTML .= "\n";
    
}

sub Debug
{
	if( $DEBUG )
	{
		print DEBUGH shift;
	}
}
1;
