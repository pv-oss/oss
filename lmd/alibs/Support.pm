# LMD Support modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package Support;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use vars qw(@ISA);
@ISA = qw(oss_base);

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
		"send"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Support' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'teachers,sysadmins' },
		 { category     => 'System' },
		 { order        => 40 },
		 { variable     => [ "sitar",       [ type => "boolean", label=>"Sitar" ] ] },
		 { variable     => [ "slapcat",     [ type => "boolean", label=>"Slapcat" ] ] },
		 { variable     => [ "supportText", [ type => "text"   , label=>"Content", rows=>"20", cols=>"60" ] ] },
		 { variable     => [ "subject",     [ type => "string"   , style => "width:200px" ] ] },
		 { variable     => [ "contact",     [ type => "string"   , style => "width:200px" ] ] },
		 { variable     => [ "email",       [ type => "string"   , style => "width:200px" ] ] },
		 { variable     => [ "regcode",     [ type => "string"   , style => "width:200px" ] ] },
		 { variable     => [ "support_email", [ type => "string"   , style => "width:200px" ] ] },
		 { variable     => [ "cc_email",    [ type => "string"   , style => "width:450px", help => 'Ex.: mail_addr1@extis.de,mail_addr2@gmail.com,addr3@extis.de,.....' ] ] },
	];
}

sub default
{
	my $this        = shift;
	my $reply       = shift;
	my $subject     = $reply->{subject} || "";
	my $contact     = $reply->{contact} || $this->get_attribute(main::GetSessionValue('dn'),'cn');
	my $regcode;
	my $support_email ;
	my $supportText = $reply->{supportText} || "";
	my @ret;

	if(exists($reply->{warning})){
		push @ret, { NOTICE => $reply->{warning}};
	}

	if(exists($reply->{regcode})){
		$regcode = $reply->{regcode};
	}else{
		$regcode = $this->{SYSCONFIG}->{SCHOOL_REG_CODE}     || 'Not yet registered';
	}

	if(exists ($reply->{support_email})){
		$support_email = $reply->{support_email};
	}else{
		$support_email = $this->{SYSCONFIG}->{SCHOOL_SUPPORT_MAIL_ADDRESS} || 'oss-support@extis.de';
	}

	my $mail   = ${$this->get_vendor_object(main::GetSessionValue('dn'),'oss','supportmailreply')}[0];
	if( ! $mail )
	{
		$mail = $this->get_attribute(main::GetSessionValue('dn'),'mail');
	}
	my $email       = $reply->{email} || $mail;
	my $cc_email    = $reply->{cc_email} || $mail;

	push @ret, { subject      => $subject };
	push @ret, { contact      => $contact };
	push @ret, { email        => $email };
	push @ret, { regcode      => $regcode };
	push @ret, { support_email=> $support_email };
	push @ret, { cc_email     => $cc_email };
	push @ret, { sitar        => 1 };
	push @ret, { slapcat      => 0 };
	push @ret, { supportText  => $supportText };
	push @ret, { action       => "send" };
	return \@ret;
}

sub send
{
	my $this   = shift;
	my $reply  = shift;

	if( $reply->{email} !~ /\w+\@\w+/ )
	{
		$reply->{warning} = main::__("You have to provide a valid E-Mail address");
		return $this->default($reply);
	}
	$this->create_vendor_object(main::GetSessionValue('dn'),'oss','supportmailreply',$reply->{email});
	if( $reply->{support_email} !~ /\w+\@\w+/ )
	{
		$reply->{warning} = main::__("You have to provide a valid Support E-Mail address");
		return $this->default($reply);
	}
	if( $reply->{subject} =~ /^\s*$/ )
	{
		$reply->{warning} = main::__("You have to provide a short description of your problem");
		return $this->default($reply);
	}
	if( $reply->{supportText} =~ /^\s*$/ )
	{
		$reply->{warning} = main::__("You have to provide a description of your problem");
		return $this->default($reply);
	}
	my @mail_address = split /,/, $reply->{cc_email};
	foreach my $mail (sort @mail_address){
		if( $mail !~ /\w+\@\w+/ ){
			$reply->{warning} = "Incorrect e-mail address (CC) : $mail";
			return $this->default($reply);
		}else{
			$reply->{support_email} .= ", ".$mail;
		}
	}

	my $SUPPORT = 'SUBJECT="'.$reply->{subject}."\"\n".
	              'REGCODE="'.$reply->{regcode}."\"\n".
		      'CONTACT="'.$reply->{contact}."\"\n".
		      'MAILFROM="'.$reply->{email}."\"\n".
		      'MAILTO="'.$reply->{support_email}."\"\n";
	if( $reply->{slapcat} )
	{
		      $SUPPORT .= 'SLAPCAT="yes"'."\n";
	}
	if( $reply->{sitar} )
	{
		      $SUPPORT .= 'SITAR="yes"'."\n";
	}
	write_file('/tmp/SUPPORT',$SUPPORT);
	write_file('/tmp/SUPPORT-BODY',$reply->{supportText});
	system('/usr/share/oss/tools/make_support &');

	$SUPPORT =~ s/\n/<br>/gm;

	return { TYPE => 'NOTICE' , MESSAGE1 => 'Your support question was sent', MESSAGE2_NOTRANSLATE => $SUPPORT };

}

1;
