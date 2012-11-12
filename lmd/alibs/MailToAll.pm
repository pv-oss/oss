# LMD MailToAll modul
# Copyright (c) 2012 EXTIS GmbH Germany
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package MailToAll;

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
		"send",
	];

}

sub getCapabilities
{
	return [
		{ title        => 'Mail To All' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ category     => 'System' },
		{ order        => 41 },
		{ variable     => [ "mailtoallText",            [ type => "text", label=>"Content", rows=>"20", cols=>"60" ] ] },
		{ variable     => [ "class",                    [ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "workgroup",                [ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "role",                     [ type => "list", size=>"10",  multiple=>"true" ] ] },
		{ variable     => [ "all_users",                [ type => "boolean" ] ] },
	];
}

sub default
{
	my $this    = shift;
	my $reply   = shift;
	my $subject = $reply->{subject} || '';
	my $contact = $reply->{contact} || $this->get_attribute(main::GetSessionValue('dn'),'cn');
	my $mailtoallText = $reply->{mailtoallText} || '';
	my @ret;

	if(exists($reply->{warning})){
		push @ret, { NOTICE => $reply->{warning}};
	}

	my $mail   = ${$this->get_vendor_object(main::GetSessionValue('dn'),'oss','supportmailreply')}[0];
	if( ! $mail )
	{
		$mail = $this->get_attribute(main::GetSessionValue('dn'),'mail');
	}
	my $sender  = $reply->{sender} || $mail;

	my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
	my @groups = ('groups' );
	push @groups, { head => [ 'role', 'class', 'workgroup' ]};
	push @groups, { line => [ 'one',
					{ role         => $roles },
					{ class        => $classes },
					{ workgroup    => $workgroups },
			]};

	push @ret, { table        => \@groups };
	push @ret, { all_users    => '' };
	push @ret, { subject      => $subject };
	push @ret, { contact      => $contact };
	push @ret, { sender       => $sender };
	push @ret, { mailtoallText  => $mailtoallText };
	push @ret, { action       => "send" };
	return \@ret;
}

sub send
{
	my $this   = shift;
	my $reply  = shift;

	if( $reply->{subject} =~ /^\s*$/ )
        {
		$reply->{warning} = main::__('Please enter one subject!');
		return $this->default($reply);
	}
	if( $reply->{sender} !~ /\w+\@\w+/ )
	{
		$reply->{warning} = main::__('You have to provide a valid E-Mail address!');
		return $this->default($reply);
	}
	if( $reply->{mailtoallText} =~ /^\s*$/ )
	{
		$reply->{warning} = main::__('Please enter your email content!');
		return $this->default($reply);
	}

	if( ($reply->{all_users}) and ($reply->{groups}->{one}->{role} or $reply->{groups}->{one}->{class} or $reply->{groups}->{one}->{workgroup}) ){
		$reply->{warning} = main::__('Please check only all_users to select or chose the groups !');
		return $this->default($reply);
	}
	if( !$reply->{all_users} and !$reply->{groups}->{one}->{role} and !$reply->{groups}->{one}->{class} and !$reply->{groups}->{one}->{workgroup} ){
		$reply->{warning} = main::__('Please check from all_users or from select the groups !');
		return $this->default($reply);
	}

	$reply->{mail_to} = '';
	if($reply->{all_users}){
		my @all_user = @{$this->get_school_users('*')};
		foreach my $user_dn (@all_user){
			my $mail_address = $this->get_attribute("$user_dn", 'mail');
			if($mail_address){
				$reply->{mail_to} .= $mail_address.", ";
			}
		}
	}else{
		my @role        = split /\n/, $reply->{groups}->{one}->{role}  || ();
		my @workgroup   = split /\n/, $reply->{groups}->{one}->{workgroup} || ();
		my @class       = split /\n/, $reply->{groups}->{one}->{class} || ();
		print Dumper(@role)."\n".Dumper(@class)."\n".Dumper(@workgroup)."\n";

		my $user        = $this->search_users('*',\@class,\@workgroup,\@role);
		foreach my $user_dn ( sort keys %{$user} ){
			my $mail_address = $this->get_attribute("$user_dn", 'mail');
			if($mail_address){
				$reply->{mail_to} .= $mail_address.", ";
			}
		}
	}

	my $MAIL_TO_ALL='SUBJECT="'.$reply->{subject}."\"\n".
			'CONTACT="'.$reply->{contact}."\"\n".
			'MAILFROM="'.$reply->{sender}."\"\n".
			'MAILTO="'.$reply->{mail_to}."\"\n";

	write_file('/tmp/MAIL_TO_ALL',$MAIL_TO_ALL);
        write_file('/tmp/MAIL_TO_ALL-BODY',$reply->{mailtoallText});
        system('/usr/share/oss/tools/make_mail_to_all &');
	$MAIL_TO_ALL =~ s/\n/<br>/gm;

	return { TYPE => 'NOTICE' , MESSAGE1 => 'Your mail was sent for all users', MESSAGE2_NOTRANSLATE => $MAIL_TO_ALL };
}

1;
