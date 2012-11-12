# LMD WhiteLists modul
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package WhiteLists;

use strict;
use oss_pedagogic;
use oss_utils;
use Data::Dumper;
use vars qw(@ISA);
@ISA = qw(oss_pedagogic);
my $XML = undef;

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_pedagogic->new($connect);
    $self->{WhiteListsBase} = 'ou=WhiteLists,'.$self->{SCHOOL_BASE};
    $self->{roomDN}         = $self->get_room_by_name(main::GetSessionValue('room'));
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"filetree_dir_open",
		"activate",
		"deactivate",
		"deactivateAll",
		"edit",
		"modify",
		"delete",
		"deleteRealy",
		"newCategory",
		"addNewCategory",
		"modifyCategory",
		"newWhiteList",
		"addNewWhiteList",
		"overview",
		"deactivateAll_in_this_room"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'White Lists' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'teachers' },
		 { allowedRole  => 'teachers,sysadmins' },
		 { category     => 'Proxy' },
		 { order        => 40 },
		 { variable     => [ "whiteList",        [ type => "filetree", label=>"Categories/Lists", can_choose_dir => "true", show_selected_item => "label" ] ] },
		 { variable     => [ "whiteListContent", [ type => "text"    , label=>"Content" ] ] },
		 { variable     => [ "cn",               [ type => "string"  , label=>"cn", backlabel=>"in english please" ] ] },
		 { variable     => [ "awl",              [ type => "label"  , label=>'Activated White Lists:'  ] ] },
		 { variable     => [ "wlbase",           [ type => "hidden" ] ] }
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
	my $this       = shift;
	my $reply      = shift;
	my $whiteLists = undef;
	my $content    = undef;
	my $LANG       = main::GetSessionValue('lang');
	my @ret        = ();

	$this->get_lists_recursive($this->{WhiteListsBase},$reply->{whiteList});
	push @ret, { whiteList        => $XML };

	if( $this->{roomDN} )
	{
		my @whiteLists = ( 'lists' );
		foreach my $wl ( @{$this->get_vendor_object($this->{roomDN},'oss','whiteLists')} )
		{
			my $label = get_name_of_dn($wl);
			my $des   = $this->get_attribute($wl,'description');
			if( $des  =~ /^NAME-$LANG=(.*)$/m)
			{
				$label = $1;
			}
			push @whiteLists, { line => [ 1 , { awl => $label } ] };
		}
		if( scalar(@whiteLists) > 1  )
		{
			push @ret, { table    => \@whiteLists  };
		}

		push @ret, { rightaction      => "activate" };
		push @ret, { rightaction      => "deactivate" };
		push @ret, { rightaction      => "deactivateAll" };
	}

	if( main::GetSessionValue('role') =~ /sysadmins|root$/ )
        {
		push @ret, { rightaction      => "overview" };
        }

	push @ret, { rightaction      => "edit" };
	push @ret, { rightaction      => "delete" };
	push @ret, { rightaction      => "newCategory" };
	if( $reply->{whiteList} ){
		push @ret, { rightaction      => "newWhiteList" };
	}
	push @ret, { rightaction      => "cancel"};
	return \@ret;
}

sub get_lists_recursive
{
	my $this     = shift;
	my $aktPath  = shift;
	my $path     = shift || '######';
	my $LANG     = main::GetSessionValue('lang');
	my @dirs     = ();
	my @files    = ();
	my $sorted   = {};

	my $categories = $this->get_whitelist_categories($aktPath);
	foreach my $dn ( keys %$categories )
	{
		my $label = $categories->{$dn}->{ou}->[0];
		if($categories->{$dn}->{description}->[0] =~ /^NAME-$LANG=(.*)$/m)
		{
			$label = $1;
		}
		$sorted->{$label} = $dn;
	}
	foreach my $l ( sort keys %$sorted )
	{
		my $dn = $sorted->{$l};
		my $label = $categories->{$dn}->{ou}->[0];
		if($categories->{$dn}->{description}->[0] =~ /^NAME-$LANG=(.*)$/m)
		{
			$label = $1;
		}
		if( $path =~ /$dn$/ )
		{
			$XML .= '<dir label="'.$label.'" path="'.$dn.'"'.">\n";
			$this->get_lists_recursive($dn,$path);
			$XML .= '</dir>';
		}
		else
		{
			$XML .= '<dir label="'.$label.'" path="'.$dn.'"'."/>\n";
		}
	}
	if($aktPath eq $path)
	{
		my $wl = $this->get_whitelists($aktPath);
		foreach my $dn ( keys %$wl )
		{
			my $label = $wl->{$dn}->{cn}->[0];
			if( $wl->{$dn}->{description}->[0] =~ /^NAME-$LANG=(.*)$/m )
			{
				$label = $1;
			}
			if( $this->check_vendor_object( $this->{roomDN}, 'oss', 'whiteLists' , $dn ) )
			{
				$label = '* '.$label.' *';
			}
			$XML .= '<file label="'.$label.'" path="'.$dn.'"'."/>\n";
		}

	}
}

sub newCategory
{
	my $this    = shift;
        my $reply   = shift;
        my $name    = '';
        my $wlbase   = $reply->{whiteList} || $this->{WhiteListsBase};
	my @ret;

	if($reply->{whiteList} =~ /^cn=(.*)$/ ){
		return [
			{ NOTICE => main::__('In this file you can not create a new Category !')}
		];
	}
	if($reply->{warning}){
		push @ret, { NOTICE => "$reply->{warning}"};
	}

        if( $reply->{whiteList} ne '' )
        {
                $name = $this->showReadablePath($wlbase);
        }else{
		$name = $name;
	}

	push @ret, { notranslate_subtitle  => $name.main::__('newCategory') };
	push @ret, { cn          => "$reply->{cn}" };
	push @ret, { description => "$reply->{description}" };
	push @ret, { wlbase      => $wlbase };
	push @ret, { action      => "cancel" };
	push @ret, { name        => 'action', value => 'addNewCategory',  attributes => [ label => 'insert' ] };
	return \@ret;
}

sub addNewCategory
{
	my $this    = shift;
	my $reply   = shift;
	my $war_mess = '';

	if($reply->{cn} eq ""){
		$war_mess .= main::__('Please enter a Category name !<br>');
	}
	if($reply->{description} eq ""){
		$war_mess .= main::__('Please enter a Category description !<br>');
	}
	if( $war_mess ne ''){
		$reply->{warning} = $war_mess;
		return $this->newCategory($reply);
	}
	
	my $desc    = 'NAME-EN='.$reply->{cn}."\nNAME-".main::GetSessionValue('lang').'='.$reply->{description};
	$this->add_whitelist_category($reply->{cn},$desc,$reply->{wlbase});
	$reply->{whiteList} = $reply->{wlbase};
	$this->default($reply);
}

sub newWhiteList
{
	my $this    = shift;
	my $reply   = shift;
	my @ret;

	if($reply->{whiteList} =~ /^cn=(.*)$/ ){
		return [
			{ NOTICE => main::__('In this file you can not create a new WhiteList !')}
		];
	}
	if($reply->{bad_list}){
		my $domains = join "\n",@{$reply->{bad_list}};
		push @ret, { NOTICE => main::__('Incorrect domain definition in the list.Example of good domain definitions: extis.de or download.suse.com (specify one domaine per line)')};
		push @ret, { notranslate_subtitle  => $this->showReadablePath($reply->{wlbase}).main::__('newWhiteList')};
		push @ret, { cn        => $reply->{cn}};
		push @ret, { description => $reply->{description} };
		push @ret, { whiteListContent => $domains };
		push @ret, { wlbase      => $reply->{wlbase} };
		push @ret, { action      => "cancel" };
		push @ret, { name => 'action', value => 'addNewWhiteList',  attributes => [ label => 'insert' ] };
		return \@ret;
	}else{
		if($reply->{warning}){
			push @ret, { NOTICE => "$reply->{warning}"};
		}
		push @ret, { notranslate_subtitle  => $this->showReadablePath($reply->{whiteList}).main::__('newWhiteList')};
		push @ret, { cn        => $reply->{cn} };
		push @ret, { description => $reply->{description} };
		push @ret, { whiteListContent => $reply->{whiteListContent} };
		push @ret, { wlbase      => $reply->{whiteList} };
		push @ret, { action      => "cancel" };
		push @ret, { name => 'action', value => 'addNewWhiteList',  attributes => [ label => 'insert' ] };
		return \@ret;
	}
}

sub addNewWhiteList
{
	my $this    = shift;
	my $reply   = shift;
	my @content = split /\n/, $reply->{whiteListContent};
        my @end_godlist;
        my ($good_list, $bad_list)    = check_domain_name_for_proxy(\@content);
	my $war_mess = '';

	if($reply->{cn} eq ""){
                $war_mess .= main::__('Please enter a WhiteList name !<br>');
        }
	if($reply->{description} eq ""){
                $war_mess .= main::__('Please enter a description !<br>');
        }
	if($reply->{whiteListContent} eq ""){
		$war_mess .= main::__('Please give at least one domain if you want to save the WhiteList !<br>');
	}
	if( $war_mess ne ''){
		$reply->{warning} = $war_mess;
		$reply->{whiteList} = $reply->{wlbase};
		return $this->newWhiteList($reply);
	}

	if( scalar(@$bad_list) ){
		$reply->{bad_list} = $bad_list;
		$reply->{goods} = $good_list;
		$this->Save($reply);
                $this->newWhiteList($reply);
        }else{
		$reply->{goods} = $good_list;
		$this->Save($reply);
		$reply->{whiteList} = $reply->{wlbase};
		$this->default($reply);
	}
}

sub Save
{
	my $this  = shift;
	my $reply = shift;
	my $base  = $reply->{wlbase};
	my $cn = $reply->{cn};
	my $desc    = 'NAME-EN='.$reply->{cn}."\nNAME-".main::GetSessionValue('lang').'='.$reply->{description};

	my $dn = 'cn='.$cn.','.$base;
	my $exists_whitelist_dn = $this->exists_dn($dn);

	if( $exists_whitelist_dn eq 0){
		my $goods = $reply->{goods};
		if( scalar(@$goods)){
			$this->add_whitelist($reply->{wlbase},$reply->{cn},$desc,$reply->{goods});
		}else{
			$this->add_whitelist($reply->{wlbase},$reply->{cn},$desc);
		}
	}else{
		my $wlbase  = $reply->{wlbase};
		my $entry   = $this->get_entry($dn,1);
		my @allowed = $this->get_attribute( $dn, 'allowedDomain');
		foreach(@{$reply->{goods}}){
			push @allowed, $_;
		}
		$entry->replace( allowedDomain => \@allowed );
		$entry->update( $this->{LDAP} );
	}	
}

sub delete
{
	my $this    = shift;
	my $reply   = shift;
	my $LANG    = main::GetSessionValue('lang');
	my $tmp     = '';
	my $desc    = $this->get_attribute($reply->{whiteList},'description');

	if( !$reply->{whiteList} ){
		return $this->default();
	}

	if( $desc =~ /^NAME-$LANG=(.*)$/m)
	{
		$tmp = $1;
		if( $desc =~ /^DESC-$LANG=(.*)$/m)
		{
			$tmp .= "\n".$1;
		}
	}
	else
	{
		$tmp = get_name_of_dn($reply->{whiteList});
	}
	
	return [
		{ subtitle    => "Do you realy want to delete this WhiteList(s)" },
		{ label       => $tmp },
		{ wlbase      => $reply->{whiteList} },
		{ action      => "cancel" },
		{ name => 'action', value => 'deleteRealy',  attributes => [ label => 'delete' ] }
	];
}

sub deleteRealy
{
	my $this    = shift;
	my $reply   = shift;
	$this->delete_ldap_children($reply->{wlbase});
	$this->{LDAP}->delete($reply->{wlbase});
	$this->default();
}

sub edit
{
	my $this    = shift;
	my $reply   = shift;
	my $wlbase  = $reply->{whiteList};
	my $entry   = $this->get_entry($wlbase);
	my @ret;

	if( $entry->{objectclass}->[0] eq 'WhiteList' )
	{
		if($reply->{bad_list}){
			my $domains = join "\n",@{$reply->{bad_list}};
			push @ret, { subtitle     => main::__('edit_whitelist') };
			push @ret, { NOTICE => main::__('Incorrect domain definition in the list.Example of good domain definitions: extis.de or download.suse.com (specify one domaine per line)')};
			push @ret,{ label            => $entry->{cn}->[0] };
                        push @ret,{ name => 'description',  value => $entry->{description}->[0], attributes => [ type => 'text' ] };
                        push @ret,{ whiteListContent => $domains };
                        push @ret,{ wlbase           => $wlbase };
                        push @ret,{ action           => "cancel" };
                        push @ret,{ name => 'action', value => 'modify',  attributes => [ label => 'apply' ] };
			push @ret,{ name => 'flag', value => 'bad', attributes => [ label => 'hidden'] };
			return \@ret;
		}else{
			my $domains = '';
			push @ret, { subtitle     => main::__('edit_whitelist') };
			if( exists($entry->{alloweddomain}) ){
				$domains = join "\n",@{$entry->{alloweddomain}};
			}
			if($reply->{warning}){
				 push @ret, { NOTICE => "$reply->{warning}"};
			}
			push @ret,{ label            => $entry->{cn}->[0] };
			push @ret,{ name => 'description',  value => $entry->{description}->[0], attributes => [ type => 'text' ] };
			push @ret,{ whiteListContent => $domains };
			push @ret,{ wlbase           => $wlbase };
			push @ret,{ action           => "cancel" };
			push @ret,{ name => 'action', value => 'modify',  attributes => [ label => 'apply' ] };
			return \@ret;
		}
	}elsif( $entry->{objectclass}->[0] eq 'organizationalUnit'){
		push @ret, { subtitle     => main::__('edit_category') };
		push @ret, { label            => $entry->{ou}->[0] };
		push @ret, { name => 'description',  value => $entry->{description}->[0], attributes => [ type => 'text' ] };
		push @ret, { name => 'category_dn', value => "$reply->{whiteList}",  attributes => [ type => 'hidden' ] };
		push @ret, { action => "cancel" };
		push @ret, { name => 'action', value => 'modifyCategory',  attributes => [ label => 'apply' ] };
		return \@ret;
	}

	$this->default($reply);
}

sub modify
{
	my $this    = shift;
	my $reply   = shift;
	my $wlbase  = $reply->{wlbase};
	my $entry   = $this->get_entry($wlbase,1);
	my @content = split /\n/, $reply->{whiteListContent};
	my ($good_list, $bad_list)    = check_domain_name_for_proxy(\@content);
	my $war_mess = '';

        if($reply->{description} eq ""){
                $war_mess .= main::__('Please enter a description !<br>');
        }
        if($reply->{whiteListContent} eq ""){
                $war_mess .= main::__('Please give at least one domain if you want to save the WhiteList! <br>');
        }
        if( $war_mess ne ''){
                $reply->{warning} = $war_mess;
                $reply->{whiteList} = $wlbase;
                my $ret = $this->edit($reply);
                return $ret;
        }


	if( scalar(@$bad_list) ){
		$reply->{bad_list}= $bad_list;

		if($reply->{flag}){
			my @allowed = $this->get_attribute( $wlbase, 'allowedDomain');
	                foreach(@{$good_list}){
	                        push @allowed, $_;
	                }
			$entry->replace( allowedDomain => \@allowed );
		}else{
                        $entry->replace( allowedDomain => $good_list );
                }
                $entry->update( $this->{LDAP} );

		$reply->{whiteList} = $wlbase;
		$this->edit($reply);
	}else{
		my $desc    = $entry->get_value('description');
	        if( $desc ne $reply->{description} )
	        {
	                $entry->replace( description => $reply->{description} );
	        }

		if($reply->{flag}){
			my @allowed = $this->get_attribute( $wlbase, 'allowedDomain');
	                foreach(@{$good_list}){
		                push @allowed, $_;
	                }
			$entry->replace( allowedDomain => \@allowed );
		}else{
			$entry->replace( allowedDomain => $good_list );
		}
		$entry->update( $this->{LDAP} );

	        $reply->{whiteList} = $wlbase;
	        $this->edit($reply);
	}
}

sub activate
{
	my $this    = shift;
	my $reply   = shift;
	$this->activate_whitelist($reply->{whiteList},$this->{roomDN});
	$this->default($reply);
}

sub deactivate
{
	my $this    = shift;
	my $reply   = shift;
	$this->deactivate_whitelist($reply->{whiteList},$this->{roomDN});
	$this->default($reply);
}

sub deactivateAll
{
	my $this    = shift;
	my $reply   = shift;
	foreach my $wl ( @{$this->get_vendor_object($this->{roomDN},'oss','whiteLists')} )
	{
		$this->deactivate_whitelist($wl,$this->{roomDN});
	}
	$this->default($reply);
}

sub showReadablePath
{
	my $this    = shift;
	my $path    = shift;
	my $LANG    = main::GetSessionValue('lang');
	my $name    = '';
	do {
		my $tmp = $this->get_attribute($path,'description');
		if( $tmp =~ /^NAME-$LANG=(.*)$/m )
		{
			$name = $1.'->'.$name;
		}
		else
		{
			$name = get_name_of_dn($path).'->'.$name;
		}
		$path = get_parent_dn($path);
	} until ( $path eq 'ou=WhiteLists,'.$this->{SCHOOL_BASE} );
	return $name
}

sub overview
{
	my $this    = shift;
	my $LANG     = main::GetSessionValue('lang');
	my @whiteLists;
	my @lines = ('white_list');
	my $rooms    = $this->get_rooms('all');

	foreach my $roomDN (keys %{$rooms})
        {
		my $room_name = $this->get_attribute($roomDN,'description');
		my @label_white_list;
		my @description_white_list;
		my $white_list = '';
                foreach my $wl ( @{$this->get_vendor_object($roomDN,'oss','whiteLists')} )
                {
                        my $label = get_name_of_dn($wl);
			push @label_white_list, $label;
			$white_list .= $label."<br>"; 
                }
		push @lines, { line => [ "$roomDN",
		                               { name => "room_name", value => "$room_name", "attributes" => [type => "label", style => "width:120px"] },
		                               { name => "white_list", value => "$white_list" , "attributes" => [type => 'label', style => "width:120px"] },
				]};

	}

	push @whiteLists, { label => 'All rooms on the positiv list '};
	push @whiteLists, { table => \@lines};
	push @whiteLists, { action => 'cancel'};
	push @whiteLists, { action => 'deactivateAll_in_this_room'};

	return \@whiteLists;
}

sub deactivateAll_in_this_room
{
	my $this  = shift;
	my $reply = shift;
	my $rooms    = $this->get_rooms('all');

        foreach my $roomDN (keys %{$rooms})
        {
		foreach my $wl ( @{$this->get_vendor_object("$roomDN",'oss','whiteLists')} )
	        {
	                $this->deactivate_whitelist($wl,$roomDN);
	        }
	}
        $this->overview;
}

sub modifyCategory
{
	my $this  = shift;
	my $reply = shift;
	my $entry   = $this->get_entry($reply->{category_dn},1);
	my $desc    = $entry->get_value('description');

	if( $desc ne $reply->{description} )
	{
		$entry->replace( description => $reply->{description} );
	}
	$entry->update( $this->{LDAP} );

	$this->default();
}

1;
