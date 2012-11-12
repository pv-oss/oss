# LMD ManageFileSystem modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageFileSystem;

use strict;
use oss_base;
use oss_utils;
use MIME::Base64;
use vars qw(@ISA);
use Data::Dumper;
@ISA = qw(oss_base);
use Encode qw(encode decode);

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
		"showACL",
		"set",
		"addAcl",
		"setAcl",
		"upLoad",
		"doUpload",
		"mkDir",
		"createDir",
		"downLoad",
		"filetree_dir_open"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Filesystem' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'teachers' },
		 { allowedRole  => 'students' },
		 { allowedRole  => 'teachers,sysadmins' },
		 { category     => 'System' },
		 { order        => 120 },
		 { variable     => [ "path",         [ type => "filetree", label=>"My Documents", can_choose_dir => "true" ] ] },
                 { variable     => [ "actpath",      [ type => "hidden" ] ] },
                 { variable     => [ "owner",        [ type => "string" , readonly => undef ] ] },
                 { variable     => [ "delete",       [ type => "boolean" ] ] },
                 { variable     => [ "setuid",       [ type => "boolean" ] ] },
                 { variable     => [ "setgid",       [ type => "boolean" ] ] },
                 { variable     => [ "sticky",       [ type => "boolean" ] ] },
                 { variable     => [ "recursively",  [ type => "boolean" ] ] },
                 { variable     => [ "default",      [ type => "boolean" ] ] },
                 { variable     => [ "read",         [ type => "boolean" ] ] },
                 { variable     => [ "write",        [ type => "boolean" ] ] },
                 { variable     => [ "execute",      [ type => "boolean" ] ] },
		 { variable     => [ "file",         [ type => "filefield" ] ] },
                 { variable     => [ "newowner",     [ type => "list", size=>"10", multiple=>"true" ] ] }
	];
}

sub filetree_dir_open
{
	my $this   = shift;
	my $reply  = shift;
	$this->default($reply);
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $uid    = get_name_of_dn($this->{aDN});
	my $path   = $reply->{path} || $this->get_attribute($this->{aDN},'homeDirectory');
        if( $uid eq 'Administrator' )
        {
                $uid='admin';
        }
	if( !$> && main::GetSessionValue('username') ne 'admin' )
	{
		my $tmp = $this->get_attributes(main::GetSessionValue('dn'),[ 'uidnumber', 'OXGroupID'] );
		$) = join " ",@{$tmp->{OXGroupID}};
		$> = $tmp->{uidnumber}->[0];
	}
	my $dirs = cmd_pipe("/usr/share/oss/tools/print_dir.pl","uid $uid\npath $path");
	my @r = ( { path    => $dirs } );
	if( ! -l $path  && -w $path )
	{ #do not change the acls for symlinks and if no rights
		push @r,  { rightaction 	=> 'showACL' } ;
	}

#TODO	if( ( -f $reply->{path} ) && (main::GetSessionValue('role') ne 'students' || $this->{SYSCONFIG}->{SCHOOL_STUDENTS_MAY_DOWNLOAD} eq 'yes' ))
	if(main::GetSessionValue('role') ne 'students' || $this->{SYSCONFIG}->{SCHOOL_STUDENTS_MAY_DOWNLOAD} eq 'yes' )
	{
		push @r, { rightaction   => 'downLoad' }; 
	}
#TODO	if( ( -d $reply->{path})&& ( main::GetSessionValue('role') ne 'students' || $this->{SYSCONFIG}->{SCHOOL_STUDENTS_MAY_DOWNLOAD} eq 'yes' ))
	if( main::GetSessionValue('role') ne 'students' || $this->{SYSCONFIG}->{SCHOOL_STUDENTS_MAY_UPLOAD} eq 'yes' )
	{
		push @r, { rightaction   => 'upLoad' };
		push @r, { rightaction   => 'mkDir' };
	}
	push @r, { rightaction   => 'cancel' };
	return \@r;
}

sub mkDir
{
	my $this   = shift;
	my $reply  = shift;
	my $actpath = $reply->{path}|| $this->get_attribute($this->{aDN},'homeDirectory');
	if ( ! -d $actpath  )
	{
		$actpath =~ s/\/$//;
	}
	if( ! $> && main::GetSessionValue('username') ne 'admin' )
	{
		my $tmp = $this->get_attributes(main::GetSessionValue('dn'),[ 'uidnumber', 'OXGroupID'] );
		$) = join " ",@{$tmp->{OXGroupID}};
		$> = $tmp->{uidnumber}->[0];
		if( ! -w $actpath )
		{
			return {
				TYPE => 'NOTICE',
				MESSAGE => 'You have no write permissions in this directory.',
				MESSAGE_NOTRANSLATE => $actpath 
			}
		}
	}
	return [
		{ actpath   => $actpath },
		{ notranslate_label  => $actpath },
		{ name   => 'dir', value => '',  attributes => [ type => 'string', label => 'name' ]},
		{ action => 'cancel' },
		{ name   => 'action', value   => "createDir" , attributes => [ label => 'apply' ] }
	]
	
}

sub createDir
{
	
	my $this   = shift;
	my $reply   = shift;
	my $actpath = $reply->{actpath};

	if( !$> && main::GetSessionValue('username') ne 'admin' )
	{
		my $tmp = $this->get_attributes(main::GetSessionValue('dn'),[ 'uidnumber', 'OXGroupID'] );
		$) = join " ",@{$tmp->{OXGroupID}};
		$> = $tmp->{uidnumber}->[0];
print "$) --- $>";
		if( ! -w $actpath )
		{
			return {
				TYPE => 'NOTICE',
				MESSAGE => 'You have no write permissions in this directory.',
				MESSAGE_NOTRANSLATE => $actpath 
			}
		}
	}
	my $uid  = $this->get_attribute(main::GetSessionValue('dn'),'uidnumber');
	my $gid  = $this->get_attribute(main::GetSessionValue('dn'),'gidnumber');
	my $dir = $actpath.'/'.$reply->{dir};
	$dir =~ s/'//;
	system("mkdir -p '$dir'; chown $uid:$gid '$dir'");
	$this->default({ path => $actpath });
}

sub upLoad
{
	my $this   = shift;
	my $reply  = shift;
	my $actpath = $reply->{path} || $this->get_attribute($this->{aDN},'homeDirectory');
	if ( ! -d $actpath  )
	{
		$actpath =~ s/\/$//;
	}
	if( !$> && main::GetSessionValue('username') ne 'admin' )
	{
		my $tmp = $this->get_attributes(main::GetSessionValue('dn'),[ 'uidnumber', 'OXGroupID'] );
		$) = join " ",@{$tmp->{OXGroupID}};
		$> = $tmp->{uidnumber}->[0];
		if( ! -w $actpath )
		{
			return {
				TYPE => 'NOTICE',
				MESSAGE => 'You have no write permissions in this directory.',
				MESSAGE_NOTRANSLATE => $actpath 
			}
		}
	}
	return [
		{ actpath   => $actpath },
		{ notranslate_label  => $actpath },
		{ file   => '' },
		{ action => 'cancel' },
		{ name => 'action', value => 'doUpload', attributes => [ label => 'upLoad' ] }
	]
	
}

sub doUpload
{
	my $this    = shift;
	my $reply   = shift;
	my $actpath = $reply->{actpath};
	$actpath = decode("utf8", "$actpath" );

	if( defined $reply->{file}->{content} )
	{
		if( !$> && main::GetSessionValue('username') ne 'admin' )
		{
			my $tmp = $this->get_attributes(main::GetSessionValue('dn'),[ 'uidnumber', 'OXGroupID'] );
			$) = join " ",@{$tmp->{OXGroupID}};
			$> = $tmp->{uidnumber}->[0];
			if( ! -w $actpath )
			{
				return {
					TYPE => 'NOTICE',
					MESSAGE => 'You have no write permissions in this directory.',
					MESSAGE_NOTRANSLATE => $actpath 
				}
			}
			$( = $) = join " ",@{$tmp->{OXGroupID}};
			$< = $> = $tmp->{uidnumber}->[0];
		}
		my $file = "$actpath/$reply->{file}->{filename}";
		my $tmpf = write_tmp_file($reply->{file}->{content});
		system("/usr/bin/base64 -d $tmpf >'$file'; rm $tmpf;");
	}
	$actpath = encode("utf8", "$actpath" );
	$this->default({ path => $actpath });
}

sub downLoad
{
	my $this   = shift;
	my $reply  = shift;
	my $file   = $reply->{path};
	if( ! -f $file )
	{
		return {
			TYPE => 'ERROR',
			MESSAGE => 'Only Files can be Down Loaded'
		};
	}
	my $mime = `file -b --mime-type '$file'`;  chomp $mime;
	my $tmp  = `mktemp /tmp/ossXXXXXXXX`;    chomp $tmp ;
	system("/usr/bin/base64 -w 0 '".$file."' > $tmp ");
	my $content = get_file($tmp);
	my $name    = `basename '$file'`; chomp $name;
	return [
		{ name=> 'download' , value=>$content, attributes => [ type => 'download', filename=>$name, mimetype=>$mime ] }
	];
}

sub showACL
{
	my $this   = shift;
	my $reply  = shift;
	my $uid    = get_name_of_dn($this->{aDN});
	my $path   = $reply->{path} || ''; #TODO return if no path
	my @acls   = ('acls');
	my @u      = ('unix');
	my $i      = 0;
	my $tmp    = `/usr/bin/getfacl '$path' 2> /dev/null`;
	my $unix   = {};
	my %mask   = ();
        my $setuid = ( -u $path ) || 0;
        my $setgid = ( -g $path ) || 0;
        my $sticky = ( -k $path ) || 0;

	foreach( split /\n/, $tmp )
	{
		if( /^# owner: (.*)/ )
		{
			$unix->{user}->{name} = $1; next;
		}
		if( /^# group: (.*)/ )
		{
			$unix->{group}->{name} = $1; next;
		}
		next if( /^#/ );
		my @acl = split /:/,$_;
		if( $acl[0] eq 'default' )
		{
			my $r = ( $acl[3] =~ /r/ ) ? 1 : 0;
			my $w = ( $acl[3] =~ /w/ ) ? 1 : 0;
			my $x = ( $acl[3] =~ /x/ ) ? 1 : 0;
			my %owner = ( owner => $acl[1].':'.$acl[2] );
			push @acls, { line => [ $i , { default => 1 }, {owner => $acl[1].':'.$acl[2]} , {read => $r} , {write => $w} , {execute => $x}, { delete => 0 }  ] };
			$i++;
		}
		elsif(  defined $acl[1] )
		{
			my $r = ( $acl[2] =~ /r/ ) ? 1 : 0;
			my $w = ( $acl[2] =~ /w/ ) ? 1 : 0;
			my $x = ( $acl[2] =~ /x/ ) ? 1 : 0;
			if( $acl[1] eq '' && $acl[0] ne 'mask' )
			{
				$unix->{$acl[0]}->{r} = $r;
				$unix->{$acl[0]}->{w} = $w;
				$unix->{$acl[0]}->{e} = $x;
				next;
			}
			push @acls, { line => [ $i , { default => 0 }, { owner => $acl[0].':'.$acl[1] } , {read => $r} , {write => $w} , {execute => $x} , { delete => 0 } ] };
			$i++;
		}
	}
	push @u , { line => [ 'user' , { name => $unix->{user}->{name} } , { read => $unix->{user}->{r} },  {write => $unix->{user}->{w}},{ execute => $unix->{user}->{e}} ]};
	push @u , { line => [ 'group', { name => $unix->{group}->{name} }, { read => $unix->{group}->{r} },{ write => $unix->{group}->{w}},{ execute => $unix->{group}->{e}} ]};
	push @u , { line => [ 'other', { name => 'other' } , { read => $unix->{other}->{r} }, {write => $unix->{other}->{w}},{ execute => $unix->{other}->{e}} ]};

	my @r = ({ subtitle => 'showACL'} );
	push @r, { label   => $path };
	push @r, { label   => 'Unix rights' };
	push @r, { table   => \@u };
	push @r, { label   => 'Additional bits' };
	push @r, { setuid  => $setuid };
	push @r, { setgid  => $setgid };
	push @r, { sticky  => $sticky };
	push @r, { label   => 'ACLs' }  if scalar( @acls > 1 );
	push @r, { table   => \@acls }  if scalar( @acls > 1 );
	push @r, { actpath => $path };
	push @r, { action  => "cancel" };
	push @r, { action  => "addAcl" };
	push @r, { action  => "set" };

	return \@r;
}

sub set
{
	my $this     = shift;
	my $reply    = shift;
	my $actpath  = $reply->{actpath} || ''; #TODO return if no path
	#TEST if we may do so;
	if( !$> && main::GetSessionValue('username') ne 'admin' )
	{
		my $tmp = $this->get_attributes(main::GetSessionValue('dn'),[ 'uidnumber', 'OXGroupID'] );
		$) = join " ",@{$tmp->{OXGroupID}};
		$> = $tmp->{uidnumber}->[0];
		$actpath =~ s/\/$//;
		if( ! -w $actpath )
		{
			return {
				TYPE => 'NOTICE',
				MESSAGE => 'You have no permissions to set acls on this file.',
				MESSAGE_NOTRANSLATE => $actpath 
			}
		}
	}
	my $cmd = 'chown '.$reply->{unix}->{user}->{name}.':'.$reply->{unix}->{group}->{name}." '".$actpath."' ;\n";
	my ( $u, $g, $o, $s ) = ( 0,0,0,0 );
	$u += 4 if ( $reply->{unix}->{user}->{read} );
	$u += 2 if ( $reply->{unix}->{user}->{write} );
	$u += 1 if ( $reply->{unix}->{user}->{execute} );
	$g += 4 if ( $reply->{unix}->{group}->{read} );
	$g += 2 if ( $reply->{unix}->{group}->{write} );
	$g += 1 if ( $reply->{unix}->{group}->{execute} );
	$o += 4 if ( $reply->{unix}->{other}->{read} );
	$o += 2 if ( $reply->{unix}->{other}->{write} );
	$o += 1 if ( $reply->{unix}->{other}->{execute} );
	$s += 4 if ( $reply->{setuid} );
	$s += 2 if ( $reply->{setgid} );
	$s += 1 if ( $reply->{sticky} );
	$cmd .= 'chmod '.$s.$u.$g.$o." '".$actpath."' ;\n";
	foreach( keys %{$reply->{acls}} )
	{
		if( $reply->{acls}->{$_}->{delete} )
		{
			$cmd .= 'setfacl -x '.$reply->{acls}->{$_}->{owner}." '".$actpath."' ;\n";
		}
		else
		{
			my $r = '';
			$r .= 'r' if ( $reply->{acls}->{$_}->{read} );
			$r .= 'w' if ( $reply->{acls}->{$_}->{write} );
			$r .= 'x' if ( $reply->{acls}->{$_}->{execute} );
			$cmd .= 'setfacl -m '.$reply->{acls}->{$_}->{owner}.":$r '".$actpath."' ;\n";
		}
	}
	main::Debug( $cmd );
	system($cmd);
	$this->showACL( { path => $actpath });
}

sub addAcl
{
	my $this     = shift;
	my $reply    = shift;
	my $filter   = $reply->{filter} || '*';
	my $actpath  = $reply->{actpath} || ''; #TODO return if no path
	#TEST if we may do so;
	if( !$> && main::GetSessionValue('username') ne 'admin' )
	{
		my $tmp = $this->get_attributes(main::GetSessionValue('dn'),[ 'uidnumber', 'OXGroupID'] );
		$) = join " ",@{$tmp->{OXGroupID}};
		$> = $tmp->{uidnumber}->[0];
		if( ! -w $actpath )
		{
			return {
				TYPE => 'NOTICE',
				MESSAGE => 'You have no permissions to set acls on this file.',
				MESSAGE_NOTRANSLATE => $actpath 
			}
		}
	}
	my @newowner = ();
	my $result = $this->{LDAP}->search( base   => $this->{SCHOOL_BASE},
					   filter => "(&(objectClass=schoolGroup)(name=$filter))",
					   attrs  => [ 'cn', 'description' ]
					   );
	my $entries = $result->as_struct;
	foreach my $dn ( sort keys %{$entries} )
	{
	       push @newowner, [ $dn, $entries->{$dn}->{'cn'}->[0].' ('.$entries->{$dn}->{'description'}->[0].')' ];
	}
	$result = $this->{LDAP}->search( base   => $this->{SCHOOL_BASE},
					   filter => "(&(objectClass=schoolAccount)(!(role=workstations))(!(role=templates))(name=$filter))",
					   attrs  => [ 'uid', 'cn', 'description' ]
					   );
	$entries = $result->as_struct;
	foreach my $dn ( sort keys %{$entries} )
	{
	       push @newowner, [ $dn, $entries->{$dn}->{'uid'}->[0].' '.$entries->{$dn}->{'cn'}->[0].' ('.$entries->{$dn}->{'description'}->[0].')' ];
	}
	return [
		{ label    => $actpath },
		{ filter   => $filter },
		{ newowner => \@newowner },
		{ read     => $reply->{read} },
		{ write    => $reply->{write} },
		{ execute  => $reply->{execute} },
		{ default  => $reply->{default} },
		{ recursively=> $reply->{recursively} },
		{ actpath  => $actpath },
		{ action   => "cancel" },
		{ name     => 'action', value   => "addAcl" , attributes => [ label => 'search' ] },
		{ name     => 'action', value   => "setAcl" , attributes => [ label => 'set' ] }
	]
	
}


sub setAcl
{
	my $this     = shift;
	my $reply    = shift;
	my $cmd      = '';
	foreach my $dn (split /\n/,$reply->{newowner}) 
	{
		$cmd  = 'setfacl ';
		my $n = get_name_of_dn($dn);
		$cmd .= '-d '  if( $reply->{default} );
		$cmd .= '-R '  if( $reply->{recursively} );
		$cmd .= '-m ';
		$cmd .= 'u:'   if($this->is_user($dn));
		$cmd .= 'g:'   if($this->is_group($dn));
		$cmd .= $n.':';
		$cmd .= 'r'    if( $reply->{read} );
		$cmd .= 'w'    if( $reply->{write} );
		$cmd .= 'x'    if( $reply->{execute} );
		$cmd .= " '".$reply->{actpath}."';\n";
	}
	main::Debug($cmd);
	system($cmd);
	$this->showACL( { path => $reply->{actpath} } );
}
1;
