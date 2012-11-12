# LMD WorkstationInvetarTool  modul:
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package WorkstationInventarTool;

use strict;
use oss_base;
use oss_utils;
use DBI;
use Encode ( 'encode', 'decode' );
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
		"runscript_hwinventory",
		"add_extra_info_category",
		"save_info_category",
		"delete_category",
		"save_old_info_category",
		"search",
		"filtration",
		"create_inventary_csv",
		"detailed_information",
		"save_info",
		"remove_directory",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'WorkstationInventarTool' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'Network' },
                { order        => 60 },
		{ variable     => [ "rooms",                  [ type => 'list', size => '8', multiple=>"true"] ] },
		{ variable     => [ "pc",                     [ type => 'list', size => '8', multiple=>"true", label => main::__('workstation')] ] },
		{ variable     => [ "elements",               [ type => 'list', size => '8', multiple=>"true"] ] },
		{ variable     => [ "name",                   [ type => 'label'] ] },
		{ variable     => [ "model",                  [ type => "label"] ] },
                { variable     => [ "vendor",                 [ type => "label"] ] },
		{ variable     => [ "device",                 [ type => "label"] ] },
		{ variable     => [ "start_date",             [ type => "date", style => "width:10px"] ] },
		{ variable     => [ "end_date",               [ type => "date", style => "width:10px"] ] },
		{ variable     => [ "roomlist",               [ type => "hidden"] ] },
		{ variable     => [ "detailed_information",   [ type => "action", style => "width:150px" ] ] },
		{ variable     => [ "delete_category",        [ type => "action", label => 'delete'] ] },
		{ variable     => [ "runscript_hwinventory",  [ type => "action", label => main::__('runscript_hwinventory')] ] },
		{ variable     => [ "add_extra_info_category",[ type => "action", label => main::__('add_extra_info_category')] ] },
		{ variable     => [ "save_old_info_category", [ type => "action", label => 'save'] ]},
		{ variable     => [ "model",                  [ type => "label", style => "width:100px"] ]},
		{ variable     => [ "manufacturer",           [ type => "label", style => "width:100px"] ]},
		{ variable     => [ "inventarynumber",        [ type => "label", style => "width:100px"] ]},
        ];
}

sub default
{
        my $this     = shift;
	my $reply    = shift;
        my @roomname = ('all');
        my @filter   = ();
	if($reply->{warning}){push @filter, {NOTICE => "$reply->{warning}"};}

        my $rooms    = $this->get_rooms('all');
	my @items = ('bios', 'cdrom', 'chipcard', 'cpu', 'disk', 'gfxcard', 'keyboard', 'memory', 'monitor', 'mouse', 'netcard', 'printer', 'sound', 'storage-ctrl');

	my $sth = $this->{DBH}->prepare("SELECT Id, Category_Name, Category_Label, Category_Type FROM OSSInv_PC_Info_Category");
        $sth->execute;
        my $hash_info_category = $sth -> fetchall_hashref( 'Id' );

	my @infocategory;
	foreach my $plus_info_category (keys %{$hash_info_category}){
		push @infocategory, ["inf-".$hash_info_category->{$plus_info_category}->{Category_Name},$hash_info_category->{$plus_info_category}->{Category_Label}];
	}
	@items = ( @items, @infocategory);

        foreach my $dn (keys %{$rooms})
        {
                push @roomname,  $rooms->{$dn}->{"description"}->[0];
        }
	push @roomname, '---DEFAULTS---','all';

        push @filter, { table => [ lines =>{ head =>['','','']},
                                           {line => ['search',
                                                     { name => 'filtering_by_rooms', value => main::__('filtering_by_rooms'), "attributes" =>[ type =>"label"]},
                                                     { rooms =>  [ @roomname] },
                                                     { name => 'filtering_by_elements', value => main::__('filtering_by_elements'), "attributes" =>[ type =>"label"]},
                                                     { elements => [ @items] }
                                           ]},
                       ]};

        push @filter, { NOTICE => main::__('Please select a classroom or/and a hardware device, which you want to filter.')};
        push @filter, { action => 'cancel'};
	push @filter, { action => 'runscript_hwinventory'};
	push @filter, { action => 'add_extra_info_category'};
        push @filter, { action => 'search'};
        return \@filter;

}

sub search
{
        my $this  = shift;
        my $reply = shift;
        my @filter =();
        my @pc = ('all');
        my @roomlist;
        my @elementlist;
	my @infolist;
	my %hashelements;
	my @lines = ('elements');

	my @items = split ('\n',$reply->{lines}->{search}->{elements});
        foreach my $i ( sort(@items) ){
		if($i =~ /^inf-(.*)/){
	               	push @infolist, $1;
		}else{
			push @elementlist, $i;
		}
	}

        if($reply->{lines}->{search}->{rooms} eq 'all'){
                my $rooms = $this->get_rooms('all');
                foreach my $dn (keys %{$rooms})
                {
                        push @roomlist, $rooms->{$dn}->{"description"}->[0];
                }
        }else{
                my @rl = split ('\n',$reply->{lines}->{search}->{rooms});
                foreach my $i ( sort(@rl) ){
                        push @roomlist, $i;
                }
        }

	for(my $j = 0; $j < scalar(@roomlist); $j++){
                foreach my $dn (sort( @{$this->get_workstations_of_room($roomlist[$j])}))
                {
			my $hostname = $this->get_attribute($dn,'cn');
			my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$hostname\"");
	                $sth->execute;
	                my $result = $sth->fetchrow_hashref();
	                my $pc_id = $result->{Id};
			if(defined($pc_id)){
                        	push @pc, $hostname;
			}
		}
	}


	foreach my $pc_name (@pc){
		my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$pc_name\"");
                $sth->execute;
                my $result = $sth->fetchrow_hashref();
		my $pc_id = $result->{Id};

		foreach my $components (@elementlist){
	                my $sth = $this->{DBH}->prepare("SELECT Id,PC_Id FROM OSSInv_PC_Component WHERE PC_Id=\'$pc_id\' and PC_Component_Name=\'$components\'");
	                $sth->execute;
			my $hashesref = $sth -> fetchall_hashref( 'Id' );

			foreach my $current_pc_component_id(keys %{$hashesref}){
				#get_model
				my $sth = $this->{DBH}->prepare("SELECT Component_Parameter_Value FROM OSSInv_PC_Component_Parameter WHERE PC_Component_Id=\'$current_pc_component_id\' and Component_Parameter_Name=\'Model\'");
	                        $sth->execute;
	                        my $result = $sth->fetchrow_hashref();
	                        my $current_parameter_value = $result->{Component_Parameter_Value};
				push ( @{$hashelements{$components}->{model}}, $current_parameter_value );

				#get_vendor
                                $sth = $this->{DBH}->prepare("SELECT Component_Parameter_Value FROM OSSInv_PC_Component_Parameter WHERE PC_Component_Id=\'$current_pc_component_id\' and Component_Parameter_Name=\'Vendor\'");
                                $sth->execute;
                                $result = $sth->fetchrow_hashref();
                                $current_parameter_value = $result->{Component_Parameter_Value};
				push ( @{$hashelements{$components}->{vendor}}, $current_parameter_value );

				#get_device
                                $sth = $this->{DBH}->prepare("SELECT Component_Parameter_Value FROM OSSInv_PC_Component_Parameter WHERE PC_Component_Id=\'$current_pc_component_id\' and Component_Parameter_Name=\'Device\'");
                                $sth->execute;
                                $result = $sth->fetchrow_hashref();
                                $current_parameter_value = $result->{Component_Parameter_Value};
				push ( @{$hashelements{$components}->{device}}, $current_parameter_value );

                        }
		}
	}

	foreach my $hw_component (keys %hashelements){
		foreach my $component_param(keys %{$hashelements{$hw_component}}){
			my @sort_array = sort(@{$hashelements{$hw_component}->{$component_param}});
			@{$hashelements{$hw_component}->{$component_param}} = ();
			for(my $i = 0; $i< scalar(@sort_array); $i++){
				for(my $j = $i+1; $j< scalar(@sort_array); $j++){
					if($sort_array[$i] eq $sort_array[$j]){
						$sort_array[$j] = undef;
					}
				}
			}
			for(my $i=0; $i< scalar(@sort_array); $i++){
				if( (defined $sort_array[$i]) ){
					push @{$hashelements{$hw_component}->{$component_param}}, $sort_array[$i];
				}
			}
		}
	}

	push @pc, '---DEFAULTS---','all';

	my $elementlist_length = @elementlist;
	if($elementlist_length != 0 ){
	        push @lines, { head => [
	                  { name => 'harware_class',     attributes => [ label => main::__('Hardware_Class')] },
	                  { name => 'model',             attributes => [ label => main::__('Model')]},
	                  { name => 'vendor',            attributes => [ label => main::__('Vendor')] },
	                  { name => 'device',            attributes => [ label => main::__('Device')]},
	         ]};

	        for(my $j = 0; $j < scalar(@elementlist); $j++){
	                push @lines, { line => [ "$elementlist[$j]",
	                                        { name => "name", value => "$elementlist[$j]", "attributes" => [type => "label"] },
	                                        { name => "model", value => $hashelements{$elementlist[$j]}->{model} , "attributes" => [type => 'popup'] },
	                                        { name => "vendor", value => $hashelements{$elementlist[$j]}->{vendor} , "attributes" => [type => 'popup'] },
	                                        { name => "device", value => $hashelements{$elementlist[$j]}->{device} , "attributes" => [type => 'popup'] },
	                        ]};
	        }
	}

        push @filter, { NOTICE => main::__('Please select a computer or/and a hardware device (cd-rom,disk,etc.) or the type the hardware device (ex: cd-rom:"HL-DT-ST DVDRAM GSA-T20N" ) of which you want to filter.')};
        push @filter, { roomlist => "$reply->{lines}->{search}->{rooms}" };
        push @filter, { pc => \@pc };
        push @filter, { table => \@lines};

	if( scalar(@infolist) > 0 ){
		foreach my $info_cat (@infolist){
			my $sth = $this->{DBH}->prepare("SELECT Id, Category_Label, Category_Type FROM OSSInv_PC_Info_Category WHERE Category_Name=\'$info_cat\'");
	                $sth->execute;
	                my $result = $sth->fetchrow_hashref();
	                my $info_field_type = $result->{Category_Type};
			my $info_field_label = $result->{Category_Label};
			my $info_field_id = $result->{Id};
			$sth = $this->{DBH}->prepare("SELECT Id, Info_Category_Id, Value FROM OSSInv_PC_Info WHERE Info_Category_Id=\'$info_field_id\'");
                        $sth->execute;
                        my $hashesref = $sth -> fetchall_hashref( 'Id' );
			my @info_element_values = ();
			foreach my $item (keys %{$hashesref}){
				push @info_element_values, $hashesref->{$item}->{Value};
			}
			my @sort_array = sort(@info_element_values);
			@info_element_values =();
			for(my $i = 0; $i< scalar(@sort_array); $i++){
                                for(my $j = $i+1; $j< scalar(@sort_array); $j++){
                                        if($sort_array[$i] eq $sort_array[$j]){
                                                $sort_array[$j] = undef;
                                        }
                                }
                        }
			for(my $i=0; $i< scalar(@sort_array); $i++){
                                if( (defined $sort_array[$i]) ){
                                        push @info_element_values, $sort_array[$i];
                                }
                        }
			if($info_field_type eq 'Date'){
				my @smaltable = ("info_elements", {head => ['','','','']});
				my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	                        my $Date_start = sprintf('%4d-%02d-%02d',$year,$mon,$mday);
	                        my $Date_end = sprintf('%4d-%02d-%02d',$year+1900,$mon+1,$mday);
	                        push @smaltable, { line => [ "date_$info_cat",
                                                        { name => "date", value => "$info_field_label", "attributes" => [type => "label", style => "width:150px"]},
                                                        { start_date => $Date_start},
                                                        { name => 'between', value => '  -  ', "attributes" => [type => "label", style => "width:10px"]},
                                                        { end_date => $Date_end},
                                                ]};
				push @filter, { table => \@smaltable};
			}elsif($info_field_type eq 'Text'){
				my @smaltable_text = ("info_elements", {head => ['','']});
				push @smaltable_text, { line => [ "text_$info_cat",
                                                        { name => "text", value => "$info_field_label", "attributes" => [type => "label", style => "width:150px"]},
                                                        { name => "value", value => \@info_element_values, "attributes" => [type => "popup"]},
                                                ]};
				push @filter, { table => \@smaltable_text};
			}elsif($info_field_type eq 'Number'){
                                my @smaltable_nr = ("info_elements", {head => ['','']});
                                push @smaltable_nr, { line => [ "nr_$info_cat",
                                                        { name => "nr", value => "$info_field_label", "attributes" => [type => "label", style => "width:150px"]},
                                                        { name => "value", value => \@info_element_values, "attributes" => [type => "popup"]},
                                                ]};
                                push @filter, { table => \@smaltable_nr};
			}
		}
	}

        push @filter, { action => 'cancel'};
        push @filter, { action => 'filtration'};

        return \@filter;

}

sub filtration
{
	my $this   = shift;
        my $reply =shift;
	my @ret;
	my $exists_elements;
	my $filtered_pc_list = '';

#print Dumper($reply)." reply\n";exit;
	if($reply->{warning}){
		push @ret, {NOTICE => "$reply->{warning}"};
	}

	#get 3 standard category id (Model, Manufacturer, Inventary_Number)
	my ( $category_model_id, $category_model_label) = $this->fetch_standardcategory_id_and_label('Model');
	my ( $category_manufacturer_id, $category_manufacturer_label) = $this->fetch_standardcategory_id_and_label('Manufacturer');
	my ( $category_inventarynumber_id, $category_inventarynumber_label) = $this->fetch_standardcategory_id_and_label('Inventary_Number');

	if(exists($reply->{filtered_pc_list})){
		my @filtered_pc_list = split ('\n',$reply->{filtered_pc_list});
		my @lines = ('cat', { head => [main::__("Name"),"$category_model_label", "$category_manufacturer_label", "$category_inventarynumber_label" ] } );
		foreach my $pc_name (sort @filtered_pc_list){
			my $category_model_value = $this->fetch_info_value("$pc_name", "$category_model_id");
			my $category_manufacturer_value = $this->fetch_info_value("$pc_name", "$category_manufacturer_id");
			my $category_inventarynumber_value = $this->fetch_info_value("$pc_name", "$category_inventarynumber_id");
			push @lines, { line=> [ "$pc_name",
						{ name => "pc", value => "$pc_name", attributes => [type => 'label', style => "width:100px"] },
						{ manufacturer => "$category_manufacturer_value"},
						{ model => "$category_model_value"},
						{ inventarynumber => "$category_inventarynumber_value"},
						{ detailed_information => main::__('detailed_information') },
                                                { name => "filtered_pc_list", value => $reply->{filtered_pc_list}, attributes => [type => "hidden"]},
                                    ]};
                }
		#edite and save extra information
		my $extra_info_field = $this->edite_and_save_extra_info($reply->{filtered_pc_list});

		push @ret, { table => \@lines };
		push @ret, { label => "Edite PC Info " };
	        push @ret, { table => $extra_info_field };
	        push @ret, { action => 'cancel'};
		push @ret, { name => 'action', value => 'create_inventary_csv', attributes => [ label => main::__('create_inventary_csv')]};
	        push @ret, { name => 'action', value => 'save_info', attributes => [label => main::__('save')] };
		push @ret, { name => "filteredpclist", value => "$reply->{filtered_pc_list}", attributes => [type => "hidden"]};
	        push @ret, { name => 'roomlist', value => "$reply->{roomlist}", attributes => [ type => 'hidden' ] };
	        return \@ret;
	}

	if(exists $reply->{elements}){
		$exists_elements = 1;
	}else{
		$exists_elements = 0;
	}

	if($reply->{pc} ne 'all'){
		#get_pclist
                my @pclist;
                my @pcl = split ('\n',$reply->{pc});
                foreach my $i ( @pcl ){
                        push @pclist, $i;
                }

		#filter
		my $tab = $this->select_filter($reply, $exists_elements, @pclist);

		#create page
		my @lines = ('cat',{head => [main::__("Name"),"$category_model_label", "$category_manufacturer_label", "$category_inventarynumber_label"]});
		foreach my $pc_name (sort keys %{$tab}){
                        if($tab->{$pc_name} eq 1){
				$filtered_pc_list .= $pc_name."\n";
			}
		}
		foreach my $pc_name (sort keys %{$tab}){
                        if($tab->{$pc_name} eq 1){
				my $category_model_value = $this->fetch_info_value("$pc_name", "$category_model_id");
	                        my $category_manufacturer_value = $this->fetch_info_value("$pc_name", "$category_manufacturer_id");
				my $category_inventarynumber_value = $this->fetch_info_value("$pc_name", "$category_inventarynumber_id");
				push @lines, { line=> [ "$pc_name", 
							{ name => "pc", value => "$pc_name", attributes => [type => 'label', style => "width:100px"] },
							{ manufacturer => "$category_manufacturer_value"},
							{ model => "$category_model_value"},
							{ inventarynumber => "$category_inventarynumber_value"},
							{ detailed_information => main::__('detailed_information') },
							{ name => "filtered_pc_list", value => $filtered_pc_list, attributes => [type => "hidden"]},
					]};
			}
		}
		push @ret, { table => \@lines };

	}elsif($reply->{pc} eq 'all'){
		my @roomlist;
		if($reply->{roomlist} eq 'all'){
	                my $rooms       = $this->get_rooms('all');
	                foreach my $dn (keys %{$rooms})
	                {
	                        push @roomlist, $rooms->{$dn}->{"description"}->[0];
	                }
	        }else{
	                my @rl = split ('\n',$reply->{roomlist});
	                foreach my $i ( sort(@rl) ){
	                        push @roomlist, $i;
	                }
	        }

		my @pclist;
		for(my $i=0; $i<scalar(@roomlist); $i++){
			foreach my $dn (sort( @{$this->get_workstations_of_room($roomlist[$i])}))
	                {
	                        my $hostname = $this->get_attribute($dn,'cn');
				my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$hostname\"");
	                        $sth->execute;
	                        my $result = $sth->fetchrow_hashref();
	                        my $pc_id = $result->{Id};
	                        if(defined($pc_id)){
		                        push @pclist, $hostname;
				}
	                }
                }

		my $tab = $this->select_filter($reply, $exists_elements, @pclist);

		#create page	
                my @lines = ('cat',{head => [ main::__("Name"),"$category_model_label", "$category_manufacturer_label", "$category_inventarynumber_label"]});
                foreach my $pc_name (sort keys %{$tab}){
                        if($tab->{$pc_name} eq 1){
                                $filtered_pc_list .= $pc_name."\n";
                        }
                }
                foreach my $pc_name (sort keys %{$tab}){
                        if($tab->{$pc_name} eq 1){
				my $category_model_value = $this->fetch_info_value("$pc_name", "$category_model_id");
	                        my $category_manufacturer_value = $this->fetch_info_value("$pc_name", "$category_manufacturer_id");
				my $category_inventarynumber_value = $this->fetch_info_value("$pc_name", "$category_inventarynumber_id");
                                push @lines, { line=> [ "$pc_name",
							{ name => "pc", value => "$pc_name", attributes => [type => 'label', style => "width:100px"] },
							{ manufacturer => "$category_manufacturer_value"},
							{ model => "$category_model_value"},
							{ inventarynumber => "$category_inventarynumber_value"},
							{ detailed_information => main::__('detailed_information') },
							{ name => "filtered_pc_list", value => $filtered_pc_list, attributes => [type => "hidden"]},
					]};
                        }
                }
                push @ret, { table => \@lines };
	}


	#edite and save extra information
	my $extra_info_field = $this->edite_and_save_extra_info($reply->{pc});

	push @ret, { label => "Edite PC Info " };
        push @ret, { table => $extra_info_field };
        push @ret, { action => 'cancel'};
	push @ret, { name => 'action', value => 'create_inventary_csv', attributes => [ label => main::__('create_inventary_csv')]};
	push @ret, { name => 'action', value => 'save_info', attributes => [label => main::__('save')] };
	push @ret, { name => "filteredpclist", value => "$filtered_pc_list", attributes => [type => "hidden"]};
	push @ret, { name => 'roomlist', value => "$reply->{roomlist}", attributes => [ type => 'hidden' ] };
        return \@ret;
}

sub runscript_hwinventory
{
	my $this = shift;
	my %warning ;

	my $tmp = cmd_pipe("/usr/share/oss/tools/WorkstationInventarTool_script.pl", "/usr/share/oss/tools/WorkstationInventarTool_script.pl");
=item
	if($tmp){
		$warning{'warning'} = 'The run of the WorkstationInvetarTool.pm script was a success.';
	}else{
		$warning{'warning'} = 'An error occured while running the WorkstationInvetarTool.pm script.';
	}
	$this->default(\%warning);
=cut
	$this->default;

}

sub detailed_information
{
	my $this= shift;
	my $reply = shift;
	my %hash;
	my @ret;

	push @ret, { subtitle => "$reply->{line}" };
	if( exists($reply->{cat}->{$reply->{line}}->{warning})){
		push @ret, { NOTICE => "$reply->{cat}->{$reply->{line}}->{warning}" };
	}

	#get one PC pc_id 
        my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$reply->{line}\"");
        $sth->execute;
        my $result = $sth->fetchrow_hashref();
        my $pc_id = $result->{Id};

	#select extra PC information
        $sth = $this->{DBH}->prepare("SELECT Id, Category_Name, Category_Label, Category_Type FROM OSSInv_PC_Info_Category;");
        $sth->execute;
        my $hash_info_category = $sth -> fetchall_hashref( 'Id' );

        my @pc_info = ('cat', { head => [ 'Kategori Name', 'Value' ] } );
        my $pc_name = $reply->{line};
        foreach my $info_category_id(sort keys %{$hash_info_category}){
		#get info_value
		my $sth = $this->{DBH}->prepare("SELECT Value FROM OSSInv_PC_Info WHERE PC_Name=\'$pc_name\' and Info_Category_Id=\'$info_category_id\'");
                $sth->execute;
                my $result = $sth->fetchrow_hashref();
                my $info_value = $result->{Value};

                push @pc_info, { line => [ "$info_category_id",
                                         { name => 'name', value => "$hash_info_category->{$info_category_id}->{Category_Label}", attributes => [ type => 'label'] },
                                         { name => 'value', value => "$info_value", attributes => [ type => 'label'] },
                                        ]};
        }

	push @ret, { name => "filtered_pc_list", value => "$reply->{cat}->{$pc_name}->{filtered_pc_list}", attributes => [type => "hidden"]};	
	push @ret, { name => 'pc_name', value => "$pc_name", attributes => [type => 'hidden']};
        push @ret, { label => "Extra PC Info " };
        push @ret, { table => \@pc_info };

	#select hardware informacion and show
	$sth = $this->{DBH}->prepare("SELECT Id,PC_Id, PC_Component_Name, SubComponent FROM OSSInv_PC_Component WHERE PC_Id=\'$pc_id\'");
	$sth->execute;
	my $hash_comp = $sth -> fetchall_hashref( 'Id' );

	foreach my $component_id(sort keys %{$hash_comp}){
		my @lines = ('components');
		my $sth1 = $this->{DBH}->prepare("SELECT Id, PC_Component_Id, Component_Parameter_Name, Component_Parameter_Value FROM OSSInv_PC_Component_Parameter WHERE PC_Component_Id=\'$component_id\';");
		$sth1->execute;
		my $hash_param = $sth1 -> fetchall_hashref( 'Id' );

		push @ret, { label => "$hash_comp->{$component_id}->{PC_Component_Name} / $hash_comp->{$component_id}->{SubComponent}"};

		foreach my $comp_param_id (sort keys %{$hash_param}){
			$hash_param->{$comp_param_id}->{Component_Parameter_Value} = darabolo($hash_param->{$comp_param_id}->{Component_Parameter_Value});
			$hash_param->{$comp_param_id}->{Component_Parameter_Value} =~ s/\n/<BR>/gi;
			push @lines, { line => [ "$reply->{line}",
				{name =>'param_name', value => "$hash_param->{$comp_param_id}->{Component_Parameter_Name}",  attributes =>[ type =>'label']},
				{name =>'param_value', value => "$hash_param->{$comp_param_id}->{Component_Parameter_Value}",attributes =>[ type =>'label']},
                        ]};
		}
		push @ret, { table => \@lines };

	}

	push @ret, { action => 'cancel'};
	push @ret, { action => 'filtration' }; 
	return \@ret;
}

sub save_info
{
	my $this= shift;
        my $reply = shift;

        #if has value in the reply then save tis value
	foreach my $pc_name (sort keys %{$reply->{cat}}){
	        foreach my $info_category_id (sort keys %{$reply->{extra_catinfo_value}} ){
			if($reply->{extra_catinfo_value}->{$info_category_id}->{flag} eq 1){
				my $sth = $this->{DBH}->prepare("SELECT Id, PC_Name FROM OSSInv_PC_Info WHERE Info_Category_Id=\'$info_category_id\' and Value=\'$reply->{extra_catinfo_value}->{$info_category_id}->{value}\'");
                                $sth->execute;
                                my $result = $sth->fetchrow_hashref();
                                my $is_info_id = $result->{Id};
				my $inv_num_pcname = $result->{PC_Name};
				if( ($info_category_id eq 1) and (defined $is_info_id) ){
					$reply->{warning} = 'Exists this '.$reply->{extra_catinfo_value}->{$info_category_id}->{value}.' inventarynumber, '.$inv_num_pcname;
				}else{
		                        my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC_Info WHERE PC_Name=\'$pc_name\' and Info_Category_Id=\'$info_category_id\'");
		                        $sth->execute;
		                        my $result = $sth->fetchrow_hashref();
		                        my $is_info_id = $result->{Id};
		                        if($is_info_id){
		                                $sth = $this->{DBH}->prepare("UPDATE OSSInv_PC_Info SET Value=\'$reply->{extra_catinfo_value}->{$info_category_id}->{value}\' WHERE Id=\"$is_info_id\"");
		                        }else{
		                                $sth = $this->{DBH}->prepare("INSERT INTO OSSInv_PC_Info (Id, PC_Name, Info_Category_Id, Value ) VALUES (NULL, \"$pc_name\", \"$info_category_id\", \"$reply->{extra_catinfo_value}->{$info_category_id}->{value}\");");
		                        }
		                        if($sth->execute){
		                                $reply->{warning} = main::__('The saving of the new "Pc info" has been successful');
		                        }else{
		                                $reply->{warning} = main::__('The new "Pc Info" saving was unsuccessful');
						last;
		                        }
				}
			}
	        }
	}

	$reply->{filtered_pc_list} = $reply->{filteredpclist};
	delete($reply->{cat});
	delete($reply->{label});
	delete($reply->{extra_catinfo_value});

	$this->filtration($reply);
}

sub create_inventary_csv
{
	my $this  = shift;
	my $reply = shift;

#print Dumper($reply)." a reply\n";
#exit;
	my %min_hash = ('csv');
	foreach my $pc_name (sort keys %{$reply->{cat}}){
		my $sth = $this->{DBH}->prepare("SELECT Id, PC_Name, Info_Category_Id, Value FROM OSSInv_PC_Info WHERE PC_Name=\'$pc_name\' and Info_Category_Id=\"1\"");
		$sth->execute;
		my $hashesref = $sth -> fetchall_hashref( 'Id' );

		foreach my $pc_info_id (keys %{$hashesref}){
			my $sth = $this->{DBH}->prepare("SELECT MacAddress FROM OSSInv_PC WHERE PC_Name=\"$hashesref->{$pc_info_id}->{PC_Name}\"");
			$sth->execute;
			my $result = $sth->fetchrow_hashref();
			my $macaddress = $result->{MacAddress};

			my $pc_dn   = $this->get_workstation("$macaddress");
			my $ipaddress   = $this->get_attribute($pc_dn,'dhcpStatements');
			$ipaddress =~ s/fixed-address //i;
			

			push @{$min_hash{csv}->{$hashesref->{$pc_info_id}->{Value}}->{$hashesref->{$pc_info_id}->{PC_Name}}}, $macaddress;
			push @{$min_hash{csv}->{$hashesref->{$pc_info_id}->{Value}}->{$hashesref->{$pc_info_id}->{PC_Name}}}, $ipaddress;
		}

	}

#print Dumper(%min_hash)."  mini hash\n";

	my $csv = "Inventary:Name:IP-Addr:MAC:Name 2:IP-Addr 2:MAC 2\n";
	foreach my $pc_inventary_number_id (sort keys %{$min_hash{csv}}){
		$csv .= $pc_inventary_number_id;
		foreach my $pc_name (sort keys %{$min_hash{csv}->{$pc_inventary_number_id}}){
			my $mac = $min_hash{csv}->{$pc_inventary_number_id}->{$pc_name}->[0];
			my $ip  = $min_hash{csv}->{$pc_inventary_number_id}->{$pc_name}->[1];
			$mac =~ s/:/-/g;
			$csv .= ":".$pc_name.":".$ip.":".$mac;
		}
		$csv .= "\n";
	}

#print $csv."\n  a csv\n";

	write_file('/tmp/pc_inventary_list.txt',$csv);

	my $file   = '/tmp/pc_inventary_list.txt';
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

#----------------------------------------------------------------------------------------------------------------------------------------
# START : Add or delete category
#----------------------------------------------------------------------------------------------------------------------------------------

sub add_extra_info_category
{
	my $this = shift;
	my $reply = shift;
	my @extra_category;
	my @field_type = ["Text","Date","Number","---DEFAULTS---","Text"];

	if($reply->{warning}){push @extra_category, {NOTICE => "$reply->{warning}"};}

	my $sth = $this->{DBH}->prepare("SELECT Id, Category_Name, Category_Label, Category_Type FROM OSSInv_PC_Info_Category;");
        $sth->execute;
        my $hash_info_category = $sth -> fetchall_hashref( 'Id' );

	my @lines = ('info');
	push @lines, { head => [
                          { name => 'category_id',            attributes => [ label => 'Id'] },
                          { name => 'info_field_name',        attributes => [ label => main::__('name')]},
			  { name => 'info_field_label',       attributes => [ label => main::__('label')]},
                          { name => 'info_type',              attributes => [ label => main::__('type')] },
			  { name => 'save_old_info_category', attributes => [ label => main::__('save')]},
			  { name => 'delete',                 attributes => [ label => main::__('delete')]}, 
                 ]};
	foreach my $info_category_id (sort keys %{$hash_info_category} ){
		if( ($hash_info_category->{$info_category_id}->{Category_Name} eq 'Warranty') or ($hash_info_category->{$info_category_id}->{Category_Name} eq 'BuyDate') or ($hash_info_category->{$info_category_id}->{Category_Name} eq 'Manufacturer') or ($hash_info_category->{$info_category_id}->{Category_Name} eq 'Model') or ($hash_info_category->{$info_category_id}->{Category_Name} eq 'Inventary_Number')){
			push @lines, { line => [ "$info_category_id",
                                {name =>'category_id', value => "$info_category_id",  attributes => [ type =>'label']},
                                {name =>'field_name',value => "$hash_info_category->{$info_category_id}->{Category_Name}",attributes =>[ type =>'label']},
                                {name =>'field_label',value => "$hash_info_category->{$info_category_id}->{Category_Label}",attributes =>[ type =>'string']},
                                {name =>'field_type', value => "$hash_info_category->{$info_category_id}->{Category_Type}", attributes =>[ type =>'label']},
                                {save_old_info_category => main::__('save')},
                                {name =>'info_field_hidden', value => "$hash_info_category->{$info_category_id}->{Category_Name}", attributes =>[ type =>'hidden']},
                        ]};
		}else{
			push @lines, { line => [ "$info_category_id",
                                {name =>'category_id', value => "$info_category_id",  attributes => [ type =>'label']},
                                {name =>'field_name',value => "$hash_info_category->{$info_category_id}->{Category_Name}",attributes =>[ type =>'label']},
				{name =>'field_label',value => "$hash_info_category->{$info_category_id}->{Category_Label}",attributes =>[ type =>'string']},
				{name =>'field_type', value => "$hash_info_category->{$info_category_id}->{Category_Type}", attributes =>[ type =>'label']},
				{save_old_info_category => main::__('save')},
				{delete_category => main::__('delete')},
				{name =>'info_field_hidden', value => "$hash_info_category->{$info_category_id}->{Category_Name}", attributes =>[ type =>'hidden']},
                        ]};
		}
	}

	push @extra_category, { subtitle => 'Add or delete category'};
	push @extra_category, { label => 'Existing categories :'};
	push @extra_category, { table => \@lines};
	push @extra_category, { label => 'Create new Category :'};
	push @extra_category, { name => 'field_name', value => '', attributes => [type => 'string']};
	push @extra_category, { name => 'field_label', value => '', attributes => [type => 'string']};
	push @extra_category, { name => 'field_type', value => @field_type, attributes => [type => 'popup']};
	push @extra_category, { action => 'cancel'};
	push @extra_category, { name => 'action', value => 'save_info_category', attributes => [label => main::__('save')] };

	return \@extra_category;

}

sub delete_category
{
	my $this = shift;
        my $reply = shift;
        my %warning;

	my $sth = $this->{DBH}->prepare("DELETE FROM OSSInv_PC_Info WHERE Info_Category_Id=\"$reply->{line}\";");
        $sth->execute;

        $sth = $this->{DBH}->prepare("DELETE FROM OSSInv_PC_Info_Category WHERE Id=\"$reply->{line}\";");
        if($sth->execute){
                $warning{'warning'} = sprintf( main::__('Deleted successfully the "%s" category.'), $reply->{info}->{$reply->{line}}->{info_field_hidden});
        }else{
		$warning{'warning'} = sprintf( main::__('Deletetion of the "%s" category was unsuccessful.'), $reply->{info}->{$reply->{line}}->{info_field_hidden});
        }

        $this->add_extra_info_category(\%warning);
}

sub save_info_category
{
	my $this = shift;
	my $reply = shift;
	my %warning;

	my $sth = $this->{DBH}->prepare("INSERT INTO OSSInv_PC_Info_Category (Id, Category_Name, Category_Label, Category_Type) VALUES (NULL, \'$reply->{field_name}\', \"$reply->{field_label}\", \"$reply->{field_type}\");");
	if($sth->execute){
                $warning{'warning'} = main::__('Successfully added the new "Info Category".');
        }else{
                $warning{'warning'} = main::__('Adding the new "Info Category" was unsuccessful.');
        }

	$this->add_extra_info_category(\%warning);
}

sub save_old_info_category
{
	my $this  = shift;
	my $reply = shift;
	my %warning;

	my $sth = $this->{DBH}->prepare("UPDATE OSSInv_PC_Info_Category SET Category_Label=\'$reply->{info}->{$reply->{line}}->{field_label}\' WHERE Id=\"$reply->{line}\";");
	if($sth->execute){
                $warning{'warning'} = main::__('Successfully saved the new Label.');
        }else{
                $warning{'warning'} = main::__('Save the new label was unsuccessful.');
        }

        $this->add_extra_info_category(\%warning);
}

#----------------------------------------------------------------------------------------------------------------------------------------
# END : Add or delete category
#----------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------
# Private finctions
#-----------------------------------------------------------------------

sub select_filter
{
	my $this = shift;
	my $reply = shift;
	my $exists_elements = shift;
	my @pclist = @_;
	my %finish_pc_list_elements;
	my %finish_pc_list_info;
	my @ret;

	# i select the computer's minimal hardware configurations
	my %pc;
        my %pc_and_comp;
	my %pc_and_infoelements;
	foreach my $pc_name (@pclist){
        	my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$pc_name\"");
                $sth->execute;
                my $result = $sth->fetchrow_hashref();
                my $current_pc_id = $result->{Id};
                $pc{$pc_name} = $current_pc_id;
	}

        foreach my $pc_name (keys %pc){
		#select and compare element value
        	foreach my $component (keys %{$reply->{elements}}){
                	my $sth = $this->{DBH}->prepare("SELECT Id,PC_Id,PC_Component_Name FROM OSSInv_PC_Component WHERE PC_Id=\'$pc{$pc_name}\' and PC_Component_Name=\'$component\'");
                        $sth->execute;
                        my $hashesref = $sth -> fetchall_hashref( 'Id' );
                        $pc_and_comp{$pc_name}->{$component} = $hashesref;

                        foreach my $component_id (keys %{$pc_and_comp{$pc_name}->{$component}}){
                        	my $model = $this->get_pc_comp_par_value('Model',$component_id);
                                $pc_and_comp{$pc_name}->{$component}->{$component_id}->{model} = $model;
                                my $vendor = $this->get_pc_comp_par_value('Vendor',$component_id);
                                $pc_and_comp{$pc_name}->{$component}->{$component_id}->{vendor} = $vendor;
                                my $device = $this->get_pc_comp_par_value('Device',$component_id);
                                $pc_and_comp{$pc_name}->{$component}->{$component_id}->{device} = $device;
                	}
        	}
		#select and compare info_element value
		my $sth = $this->{DBH}->prepare("SELECT Id, PC_Name, Info_Category_Id, Value FROM OSSInv_PC_Info WHERE PC_Name=\'$pc_name\'");
                $sth->execute;
                my $pc_info = $sth -> fetchall_hashref( 'Id' );
		foreach my $info_id (keys %{$pc_info}){
			my $sth = $this->{DBH}->prepare("SELECT Category_Name FROM OSSInv_PC_Info_Category WHERE Id=\'$pc_info->{$info_id}->{Info_Category_Id}\'");
	                $sth->execute;
	                my $result = $sth->fetchrow_hashref();
                        my $info_field = $result->{Category_Name};
			$pc_and_infoelements{$pc_name}->{$info_field} = $pc_info->{$info_id}->{Value}
		}
	}
#        print "\n-----------------------------------------------------------------------------------------------\n";
#	print Dumper(%pc_and_comp)."  a pc_and_comp \n";
#        print Dumper($reply->{elements})." az elements\n";

	if($exists_elements eq 1){
	#filtering
	        foreach my $component (keys %{$reply->{elements}}){
			foreach my $pc_name(keys %pc_and_comp){
				foreach my $subcomp (keys %{$pc_and_comp{$pc_name}->{$component}}){
					$reply->{elements}->{$component}->{model} =~ s/\n//gi;
					$pc_and_comp{$pc_name}->{$component}->{$subcomp}->{model} =~ s/\n//gi;
					$reply->{elements}->{$component}->{vendor} =~ s/\n//gi;
					$pc_and_comp{$pc_name}->{$component}->{$subcomp}->{vendor} =~ s/\n//gi;
					$reply->{elements}->{$component}->{device} =~ s/\n//gi;
					$pc_and_comp{$pc_name}->{$component}->{$subcomp}->{device} =~ s/\n//gi;

	                                if($reply->{elements}->{$component}->{model} ne ''){
	                                        if($reply->{elements}->{$component}->{model} eq $pc_and_comp{$pc_name}->{$component}->{$subcomp}->{model}){
	                                        	$finish_pc_list_elements{$pc_name} = 1;
	                                        }else{
	                                                $finish_pc_list_elements{$pc_name} = 0;
	                                		next;
	                                	}
	                                }else{$finish_pc_list_elements{$pc_name} = 1;}
	                                if($reply->{elements}->{$component}->{vendor} ne ''){
	                                        if($reply->{elements}->{$component}->{vendor} eq $pc_and_comp{$pc_name}->{$component}->{$subcomp}->{vendor}){
	                                        	$finish_pc_list_elements{$pc_name} = 1;
	                                        }else{
	                                                $finish_pc_list_elements{$pc_name} = 0;
	                                        	next;
	                                	}
	                                }else{$finish_pc_list_elements{$pc_name} = 1;}
	                                if($reply->{elements}->{$component}->{device} ne ''){
	                                        if($reply->{elements}->{$component}->{device} eq $pc_and_comp{$pc_name}->{$component}->{$subcomp}->{device}){
	                                        	$finish_pc_list_elements{$pc_name} = 1;
	                                        }else{
	                                        	$finish_pc_list_elements{$pc_name} = 0;
	                                        	 next;
	                                	}
	                                }else{$finish_pc_list_elements{$pc_name} = 1;}
	                                if($finish_pc_list_elements{$pc_name} eq 1){
	#	                               	last;
	                        	}
	                	}
	        	}
	        }
	}elsif($exists_elements eq 0){
		foreach my $pc_name(@pclist){
 			$finish_pc_list_elements{$pc_name} = 1;
                }
        }

	if(exists $reply->{info_elements}){
		foreach my $pc_name(keys %pc_and_infoelements){
		print $pc_name." a pc_name\n";
			foreach my $info_element (keys %{$reply->{info_elements}}){
				print "  ".$info_element." az info lement\n";
				if($info_element =~ /^date_(.*)/){
					if( ($reply->{info_elements}->{$info_element}->{start_date} le $pc_and_infoelements{$pc_name}->{$1}) and ($reply->{info_elements}->{$info_element}->{end_date} ge $pc_and_infoelements{$pc_name}->{$1}) ){
						$finish_pc_list_info{$pc_name} = 1;
					}else{
						$finish_pc_list_info{$pc_name} = 0;
						last;
					}
				}elsif($info_element =~ /^text_(.*)/){
					if($reply->{info_elements}->{$info_element}->{value} ne ''){
						my $reply_elemet_value = encode("utf8", $reply->{info_elements}->{$info_element}->{value});
						if($reply_elemet_value eq $pc_and_infoelements{$pc_name}->{$1}){
	                                                $finish_pc_list_info{$pc_name} = 1;
						}else{
	                                                $finish_pc_list_info{$pc_name} = 0;
							last;
	                                        }
					}else{$finish_pc_list_info{$pc_name} = 1;}
				}elsif($info_element =~ /^nr_(.*)/){
					if( $reply->{info_elements}->{$info_element}->{value} ne ''){
						my $reply_elemet_value = encode("utf8", $reply->{info_elements}->{$info_element}->{value});
						if($reply_elemet_value eq $pc_and_infoelements{$pc_name}->{$1}){
	                                                $finish_pc_list_info{$pc_name} = 1;
						}else{
	                                                $finish_pc_list_info{$pc_name} = 0;
							last;
	                                        }
					}else{$finish_pc_list_info{$pc_name} = 1;}
				}
			}
		}
	}else{
		foreach my $pc_name(@pclist){
                        $finish_pc_list_info{$pc_name} = 1;
                }
	}
#print "------------------------------------------------------------------------------------------\n";
#print Dumper(%finish_pc_list_elements)." a finish_pc_list_elements\n";
#print Dumper(%finish_pc_list_info)." a finish_pc_list_info\n";

	my %finish_pc_list;
	foreach my $pc_name(@pclist){
		if( ($finish_pc_list_elements{$pc_name} eq 1) and ($finish_pc_list_info{$pc_name} eq 1) ){
			$finish_pc_list{$pc_name} = 1;
		}
	}


#        print "\n--------------------- ---------------------------\n";
#        print Dumper(%finish_pc_list)." a finish_pc_list\n";
	return \%finish_pc_list;
}

sub get_pc_hwinfo_min
{
        my $this = shift;
        my $pc_name = shift;
        my @lines  = ('pc');

        push @lines, { head => [
                  { name => 'name',              attributes => [ label => main::__('Name')] },
                  { name => 'model',             attributes => [ label => main::__('Model')]},
                  { name => 'vendor',            attributes => [ label => main::__('Vendor')] },
                  { name => 'device',            attributes => [ label => main::__('Device')]},
         ]};

	#get pc_name id
	my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$pc_name\"");
        $sth->execute;
        my $result = $sth->fetchrow_hashref();
        my $current_pc_id = $result->{Id};

	#get pc_component
	$sth = $this->{DBH}->prepare("SELECT Id,PC_Id,PC_Component_Name, SubComponent FROM OSSInv_PC_Component WHERE PC_Id=\'$current_pc_id\'");
        $sth->execute;
        my $hashesref = $sth -> fetchall_hashref( 'Id' );

	foreach my $pc_component_id (sort keys %{$hashesref}){
		my $model = $this->get_pc_comp_par_value('Model',$pc_component_id);
                my $vendor = $this->get_pc_comp_par_value('Vendor',$pc_component_id);
                my $device = $this->get_pc_comp_par_value('Device',$pc_component_id);


		push @lines, { line => [ "$pc_name/$hashesref->{$pc_component_id}->{PC_Component_Name}/$pc_component_id",
                                         { name => "$hashesref->{$pc_component_id}->{PC_Component_Name}"},
                                         { model => $model || ''},
                                         { vendor => $vendor || ''},
                                         { device => $device || ''},
                                ]};
	}

	push @lines, { line => [ "$pc_name",
					{ action => 'detailed_information'},
					{ action => 'save'},
					{ action => 'remove_directory'},
                                ]};

        return \@lines;
}

sub get_pc_comp_par_value
{
	my $this = shift;
	my $comp_param_name = shift;
	my $comp_id = shift;

	my $sth = $this->{DBH}->prepare("SELECT Component_Parameter_Value FROM OSSInv_PC_Component_Parameter WHERE PC_Component_Id=\'$comp_id\' and Component_Parameter_Name=\'$comp_param_name\'");
        $sth->execute;
        my $result = $sth->fetchrow_hashref();
        my $Component_Parameter_Value = $result->{Component_Parameter_Value};
	return $Component_Parameter_Value;
}

sub fetch_standardcategory_id_and_label
{
	my $this = shift;
	my $category_name = shift;

	my $sth = $this->{DBH}->prepare("SELECT Id, Category_Label FROM OSSInv_PC_Info_Category WHERE Category_Name=\"$category_name\"");
        $sth->execute;
        my $result = $sth->fetchrow_hashref();
        my $category_id = $result->{Id};
	my $category_label = $result->{Category_Label};

	return $category_id, $category_label
}

sub fetch_info_value
{
	my $this = shift;
	my $pc_name = shift;
	my $category_id = shift;

	my $sth = $this->{DBH}->prepare("SELECT Value FROM OSSInv_PC_Info WHERE PC_Name=\"$pc_name\" and Info_Category_Id=\"$category_id\"");
	$sth->execute;
	my $result = $sth->fetchrow_hashref();
	my $value = $result->{Value};

	return $value;
}

sub edite_and_save_extra_info
{
        my $this = shift;
	my $pc = shift;

	my $show_inventary_number = 0;
	if( $pc ne 'all'){
		my @pcl = split ('\n',$pc);
#		my $valami = scalar @pcl;
#print Dumper(@pcl)." a pcl\n";
#print $valami."  valami\n";exit;
		if(scalar@pcl eq 1){
			$show_inventary_number = 1;
		}else{
			$show_inventary_number = 0;
		}
	}else{
		$show_inventary_number = 0;
	}
#print Dumper(@pcl)." a pcl\n";
#exit;

        my $sth = $this->{DBH}->prepare("SELECT Id, Category_Name, Category_Label, Category_Type FROM OSSInv_PC_Info_Category;");
        $sth->execute;
        my $hash_info_category = $sth -> fetchall_hashref( 'Id' );

        my @pc_info = ('extra_catinfo_value', { head => [ 'Kategori Name','Value', 'Save' ] } );
        foreach my $info_category_id(sort keys %{$hash_info_category}){
		if( ($hash_info_category->{$info_category_id}->{Category_Name} eq 'Inventary_Number') and ($show_inventary_number eq 0) ){}else{
                if( $hash_info_category->{$info_category_id}->{Category_Type} eq 'Date'){
                        push @pc_info, { line => [ "$info_category_id",
                                                { name => 'name', value => "$hash_info_category->{$info_category_id}->{Category_Label}", attributes => [ type => 'label'] },
                                                { name => 'value', value => "", attributes => [ type => 'date'] },
						{ name => 'flag', value => 0, attributes => [ type => 'boolean'] },
                                        ]};
                }elsif( ($hash_info_category->{$info_category_id}->{Category_Type} eq 'Text') or ($hash_info_category->{$info_category_id}->{Field_Type} eq 'Number') ){
                        push @pc_info, { line => [ "$info_category_id",
                                                { name => 'name', value => "$hash_info_category->{$info_category_id}->{Category_Label}", attributes => [ type => 'label'] },
                                                { name => 'value', value => "", attributes => [ type => 'string'] },
						{ name => 'flag', value => 0, attributes => [ type => 'boolean'] },
                                        ]};
                }
		}
        }

        return \@pc_info;
}

sub darabolo
{
	my $string = shift;
	my $new_string;
	my $length_string = length("$string");
	my $eredmeny = $length_string/90;

	if($eredmeny le 1){
		return $string;
	}else{
		$new_string = substr($string,0,90);
		$new_string .= "<br>".substr($string,91,90);
		$new_string .= "<br>".substr($string,181,90);
		$new_string .= "<br>".substr($string,271,90);
	}
	return $new_string;
}

1;
