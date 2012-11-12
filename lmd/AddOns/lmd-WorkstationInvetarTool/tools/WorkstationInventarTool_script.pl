#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use strict;
use oss_base;
use oss_utils;
use DBI;
use DBI qw(:utils);
use vars qw(@ISA);
@ISA = qw(oss_base);
use Data::Dumper;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/WorkstationInventarTool_script.pl [OPTION]'."\n".
		"With this script  we can read the workstation's hardware information from the files end saving it into the database.\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		"	No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the descriptiont.'."\n";
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	WorkstationInventarTool_script.pl'."\n".
		'DESCRIPTION:'."\n".
		"	With this script  we can read the workstation's hardware information from the files end saving it into the database\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		"		                  : No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}

my $oss    = oss_base->new();
my $rooms = $oss->get_rooms('all');
my $DBCON = 'dbi:mysql:lmd';
my $DBUSER= 'root';
my ($DBPW)= parse_file('/root/.my.cnf',"password=");

my $DBH = DBI->connect( $DBCON, $DBUSER, $DBPW);


foreach my $dnroom (keys %{$rooms})
{
        foreach my $dn ( @{$oss->get_workstations_of_room($dnroom)} )
        {
                #get hostname PC
                my $hostname = $oss->get_attribute($dn,'cn');
		my $sth = $DBH->prepare("TRUNCATE OSSInv_PC");
	        $sth->execute;
		my $sth = $DBH->prepare("TRUNCATE OSSInv_PC_Component");
                $sth->execute;
		my $sth = $DBH->prepare("TRUNCATE OSSInv_PC_Component_Parameter");
                $sth->execute;
	}
}


my %hash = ();
foreach my $dnroom (keys %{$rooms})
{
	foreach my $dn ( @{$oss->get_workstations_of_room($dnroom)} )
        {
		#get hostname PC
		my $hostname = $oss->get_attribute($dn,'cn');
		#get create time PC hwinfo
		my $datecollection = `ls -l /srv/itool/hwinfo | awk '{ if(\$8 == "$hostname"){ print \$6 \" \" \$7}}'`;
		$datecollection = trim($datecollection);		
		#get PC hardwareaddres
                my $PC_hwaddress = $oss->get_attribute($dn,'dhcpHWAddress');
                $PC_hwaddress =~ s/ethernet //;
		my @pchwinfo = ('bios', 'cdrom', 'chipcard', 'cpu', 'disk', 'gfxcard', 'keyboard', 'memory', 'monitor', 'mouse', 'netcard', 'printer', 'sound', 'storage-ctrl');

		$hash{$hostname}->{datecollection} = $datecollection;
		$hash{$hostname}->{macaddress} = $PC_hwaddress;

		for(my $i=0; $i< scalar(@pchwinfo); $i++){
                        my $file = '/srv/itool/hwinfo/'.$hostname.'/'.$pchwinfo[$i];
                        if( open(FILE,"< $file") ){
				my $subcomponent;
                                my @param;
				my $j;
				my $counter = 0;
				while(<FILE>){
                                        my $row = trim($_);
					if( $row =~ /^[0-9]{2,5}: (.*)$/ ){
						$subcomponent = $row;
					}elsif( $row =~ /^([ ]{2})([0-9A-Za-z]{1,4})(.*)$/ ){
						$row = trim1($_);
                                                @param = split(": ",$row);
						if(($param[0]) and ($param[1])){
							$hash{$hostname}->{component}->{$pchwinfo[$i]}->{$subcomponent}->{"$param[0]___$counter"}->[0]= $param[1];
							$counter++;
						}
						$j = 0;
					}elsif( $row =~ /^([ ]{4})([0-9A-Za-z]{1,4})(.*)$/ ){
						$row = trim1($_);
						$hash{$hostname}->{component}->{$pchwinfo[$i]}->{$subcomponent}->{$param[0]}->[$j] = $row;
						$j= $j+1;
                                        } 
                                }
			}
			close (FILE);
#			last;
		}
	}
}


foreach my $pc_name (keys %hash){
	#insert pc in the OSSInv_PC table
        my $sth = $DBH->prepare("INSERT INTO OSSInv_PC (Id, PC_Name, DateCollection, MacAddress) VALUES (NULL, \"$pc_name\", \"$hash{$pc_name}->{datecollection}\", \"$hash{$pc_name}->{macaddress}\");");
        $sth->execute;

        my $sth = $DBH->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$pc_name\" and MacAddress=\"$hash{$pc_name}->{macaddress}\"");
        $sth->execute;
        my $result = $sth->fetchrow_hashref();
        my $current_pc_id = $result->{Id};

	foreach my $pc_component(keys %{$hash{$pc_name}->{component}}){
		foreach my $pc_subcomponent (keys %{$hash{$pc_name}->{component}->{$pc_component}}){
			my @pc_subcomponent_split = split(": ",$pc_subcomponent);
	                #insert pc in the OSSInv_PC_Component table
	                my $sth = $DBH->prepare("INSERT INTO OSSInv_PC_Component (Id, PC_Id, PC_Component_Name, SubComponent, Component_Name, Component_Value) VALUES (NULL, \"$current_pc_id\", \"$pc_component\", \"$pc_subcomponent\", \"$pc_subcomponent_split[1]\", \"$pc_subcomponent_split[2]\");");
	                $sth->execute;

	                my $sth = $DBH->prepare("SELECT Id FROM OSSInv_PC_Component WHERE PC_Id=\'$current_pc_id\' and PC_Component_Name=\'$pc_component\' and SubComponent=\'$pc_subcomponent\' and Component_Name=\'$pc_subcomponent_split[1]\' and Component_Value=\'$pc_subcomponent_split[2]\'");
	                $sth->execute;
	                my $result = $sth->fetchrow_hashref();
	                my $current_pc_component_id = $result->{Id};

			foreach my $parameter_name (keys %{$hash{$pc_name}->{component}->{$pc_component}->{$pc_subcomponent}}){
				my $parameter_value;
				foreach my $value (@{$hash{$pc_name}->{component}->{$pc_component}->{$pc_subcomponent}->{$parameter_name}}){
					$parameter_value .= $value."\n";
				}
				if($parameter_name =~ /^(.*)(___)([0-9])/){
					$parameter_name = $1;
				}
				$parameter_value =~ s/'/\\'/; 
				#insert pc in the OSSInv_PC table
			        my $sth = $DBH->prepare("INSERT INTO OSSInv_PC_Component_Parameter (Id, PC_Component_Id, Component_Parameter_Name, Component_Parameter_Value) VALUES (NULL, \'$current_pc_component_id\', \'$parameter_name\', \'$parameter_value\');");
			        $sth->execute;
			}
		}
	}
}


$DBH->disconnect;

sub trim($)
{
        my $string = shift;
        $string =~ s/\s+$//;
        return $string;
}

sub trim1($)
{
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}
