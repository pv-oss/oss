# DNS-Management  modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package DNSManagement;

use strict;
use oss_base;
use Data::Dumper;
use MIME::Base64;
use oss_utils;
use POSIX;
use Storable qw(thaw freeze);
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
		"applyChanges",
		"create_newdomain",
		"save_newdomain",
		"delete_dom",
		"deleteRealy",
		"edit_hosts",
		"addhost",
		"save_host",
		"removehost",
		"edit_records",
		"addrecord",
		"save_record",
		"removerecord",
		"saverec",
		"switch_domain_type",
        ];

}

sub getCapabilities
{
        return [
                 { title        => 'DNS-Management' },
                 { type         => 'command' },
                 { allowedRole  => 'root' },
                 { allowedRole  => 'sysadmins' },
                 { category     => 'Network' },
                 { order        => 70 },
                 { variable     => [ "hostname",        	[ type => 'string', label => 'Host Name' ] ] },
		 { variable     => [ "domain_name",     	[ type => 'label'] ] },
		 { variable     => [ "domain_type",     	[ type => 'label'] ] },
		 { variable     => [ "domain",          	[ type => 'hidden'] ] },
		 { variable     => [ "zone",            	[ type => 'hidden'] ] },
		 { variable     => [ "record_name",     	[ type => 'label', size => 90 ] ] },
		 { variable     => [ "record_value",    	[ type => 'string', size => 90 ] ] },
		 { variable     => [ "subdomain",               [ type => 'label' ] ] },
		 { variable     => [ "relative_domain_name",    [ type => 'label' ] ] },
		 { variable     => [ "edit_hosts",              [ type => 'action' ] ] },
		 { variable     => [ "edit_records",            [ type => 'action' ] ] },
		 { variable     => [ "switch_domain_type",      [ type => 'action' ] ] },
		 { variable     => [ "delete_dom",              [ type => 'action' ] ] },
		 { variable     => [ "removehost",              [ type => 'action' ] ] },
		 { variable     => [ "saverec",                 [ type => 'action' ] ] },
		 { variable     => [ "removerecord",            [ type => 'action' ] ] },
        ];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my @lines = ( 'domains' );

	if( defined $reply->{warning}){push @ret, { NOTICE => "$reply->{warning}"}};

	my $mesg = $this->{LDAP}->search( base => $this->{SYSCONFIG}->{DNS_BASE},
                           scope => 'sub',
                           attrs => [ 'zoneName', 'suseMailDomainType'],
                           filter => '(relativeDomainName=@)' );
	if ($mesg->count == 0) {
		return [ {NOTICE => ''} ]
	}

	push @lines, { head => ['domain_name', 'domain_type', 'edit_hosts' ,'edit_records', 'switch_dom_type', 'delete_domain'] };
	my $zone_dn = "zoneName=$this->{SYSCONFIG}->{SCHOOL_DOMAIN},$this->{SYSCONFIG}->{DNS_BASE}";
	my $smdtype = $this->get_attribute($zone_dn, "suseMailDomainType");
	push @lines, { line => [ "$this->{SYSCONFIG}->{SCHOOL_DOMAIN}",
                                { domain_name => "$this->{SYSCONFIG}->{SCHOOL_DOMAIN}" },
                                { domain_type => "$smdtype" },
				{ edit_hosts => main::__('edit_hosts') },
				{ edit_records => main::__('edit_records') },
				{ name => 'domain_type', value => "$smdtype", attributes => [ type => 'hidden'] },
                     ]};

	foreach my $i ($mesg->entries) {
	        foreach my $zn ( $i->get_value('zoneName') ) {
	            if( ! ( $zn =~ /IN-ADDR\.ARPA/i ) && ! ( $zn eq $this->{SYSCONFIG}->{SCHOOL_DOMAIN} ) ) {
	                my $smdtype = $i->get_value('suseMailDomainType');
			push @lines, { line => [ "$zn",
                                                { domain_name => "$zn" },
                                                { domain_type => "$smdtype" },
						{ edit_hosts => main::__('edit_hosts') },
						{ edit_records => main::__('edit_records') },
						{ switch_domain_type => main::__('switch_dom_type') },
                                                { delete_dom  => main::__('delete_dom') },
						{ name => 'domain_type', value => "$smdtype", attributes => [ type => 'hidden'] },
                                ]};
	            }
	        }
	}

	push @ret, { table => \@lines };
	push @ret, { action => 'cancel'};
	push @ret, { action => 'create_newdomain'};
	push @ret, { action => 'applyChanges'};
	return \@ret;
}

sub create_newdomain
{
	my $this = shift;
        my $reply = shift;
        my @ret;

	if( exists($reply->{warning})){
                push @ret, {NOTICE => "$reply->{warning}"}
        }

	push @ret, { name => 'domain_name', value => '', attributes => [type => 'string']};
	push @ret, { name => 'suseMailDomainType', value => ['virtual', 'local', '---DEFAULTS---', 'virtual'], attributes => [type => 'popup']};
	push @ret, { action => 'cancel'};
        push @ret, { name => 'action', value => 'save_newdomain', attributes => [ type => 'action', label => 'apply']};
        return \@ret;
}

sub save_newdomain
{
	my $this = shift;
	my $reply = shift;
	my @ret;
	my $newdom = $reply->{domain_name};
	my $suseMailDomainType = $reply->{suseMailDomainType};
	my $wrn_msg = '';

	if( $newdom =~ /[^a-zA-Z0-9-.]+/ ) {
		$wrn_msg = main::__('Incorrect domain name entered!');
	}
	$newdom =~ /(\w+)\.(\w+)/;
	if( $newdom eq "" || ! $1 || ! $2 ) {
		$wrn_msg = main::__('Incorrect domain name entered!');
	}

	if( $wrn_msg ne ''){
		$reply->{warning} = $wrn_msg;
                $this->create_newdomain($reply);
	}else{
		my $base = 'zoneName='.$this->{SYSCONFIG}->{SCHOOL_DOMAIN}.','.$this->{SYSCONFIG}->{DNS_BASE};
		my $mesg = $this->{LDAP}->search( base => $base,
		                           scope => 'base',
		                           filter => "objectclass=dNSZone" );
		if ($mesg->count == 0) {
			return [ { NOTICE => $base." ".main::__("can't be found in LDAP.")} ];
		}

		my $zone_entry = $mesg->entry(0);

		# get out SOA and increase serial number
		my $soa = $zone_entry->get_value("sOARecord");
		my @soa = split(/ /,$soa);
		my $timestamp = $soa[2];
		my $sernr  = substr($timestamp, 8, 2);
		my $timenr = substr($timestamp, 0, 8);
		my $timenow = strftime("%Y%m%d",localtime);

		my $sernr    = '00';
		my $timenr   = $timenow;
		my $sOARecord= $soa[0]." ".$soa[1]." ".$timenr.$sernr." ".$soa[3]." ".$soa[4]." ".$soa[5]." ".$soa[6];
		my $dNSTTL   = $zone_entry->get_value('dNSTTL');
		my @mXRecord = $zone_entry->get_value('mXRecord');
		my @nSRecord = $zone_entry->get_value('nSRecord');

		# create new tree entry for the new domain
		$base = 'zoneName='.$newdom.','.$this->{SYSCONFIG}->{DNS_BASE};
		$mesg = $this->{LDAP}->add( dn    => $base,
	                        attr => [
	                                        objectClass     => ['dNSZone','suseMailDomain'],
	                                        zoneName        => $newdom,
	                                        dNSClass        => 'IN',
	                                        dNSTTL          => $dNSTTL,
	                                        sOARecord       => $sOARecord,
	                                        mXRecord        => \@mXRecord,
	                                        nSRecord        => \@nSRecord,
	                                        relativeDomainName=> '@',
	                                        suseMailDomainType=> $suseMailDomainType,
	                                        suseMailDomainMasquerading=> 'yes'
	                                 ]
	                        );


		if($mesg->code != 0) {
			return [
				{ NOTICE => main::__('Impossible to insert into ldap :').$base },
				]	
			}

		$this->default();
	}
}

sub delete_dom
{
        my $this    = shift;
        my $reply   = shift;

        return [
                { subtitle    => "Do you realy want to delete this Domain(s)" },
                { label       => $reply->{line} },
                { action      => "cancel" },
                { name => 'action', value => 'deleteRealy',  attributes => [ label => 'delete' ] },
		{ domain => "$reply->{line}" },
        ];
}

sub deleteRealy
{
	my $this = shift;
	my $reply = shift;
	my @ret;
	my $dom = $reply->{domain};

	my $mesg = $this->{LDAP}->search( base => $this->{SYSCONFIG}->{DNS_BASE},
                           scope => 'one',
                           filter => "suseMailAcceptAddress=*$reply-{line}",
                           attrs => [ 'suseMailAcceptAddress' ]);
	if ($mesg->count != 0) {
		return [
                        { NOTICE => 'Sajnalom nem torulheto mert suseMailAcceptAddress kent hasznalva van.'},
                        ]
	}

	my $base = 'zoneName='.$dom.','.$this->{SYSCONFIG}->{DNS_BASE};
	my $mesg = $this->{LDAP}->search( base => $base,
                           scope => 'one',
                           filter => "objectclass=*" );

	foreach my $i ($mesg->entries) {
	        my $mesg = $this->{LDAP}->delete( $i->dn );
	}
	$mesg = $this->{LDAP}->delete( $base );

	$this->default;
}

sub edit_hosts
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my @hosts = ( 'subdomain' );

	my $Zone = $reply->{line};

        my $mesg = $this->{LDAP}->search( base    => $this->{SYSCONFIG}->{DNS_BASE},
                                          scope   => 'sub',
                                          attrs   => ['dn'],
					  filter  => '(&(zoneName='.$Zone.')(objectClass=top)(objectClass=dNSZone)(aRecord=*)(!(relativeDomainName=@))(!(objectClass=DHCPEntry)))'
                );
        if( $mesg->code)
        {
                $this->ldap_error($mesg);
                return undef;
        }

	push @hosts,{ head => ['RelativeDomainName', 'aRecord', 'delete'] };
	foreach my $entry ($mesg->entries){
		my $host_dn = $entry->dn;
		my $subdomain_ip = $this->get_attribute( $host_dn,'aRecord');
                my $rel_dom_name = $this->get_attribute( $host_dn,'relativeDomainName');

		push @hosts,{ line=> [ "$host_dn",
					{ relative_domain_name => "$rel_dom_name" },
                                        { name => 'aRecord', value => "$subdomain_ip", attributes => [ type => 'label']},
                                        { removehost => main::__('delete') },
                                        { zone => "$reply->{line}" }
                                   ]};
	}

	push @ret, { subtitle => "Edit Hosts" };
        push @ret, { label => main::__('domain_name').": $Zone" };
	if(scalar(@hosts) > 2){
		push @ret, { table => \@hosts };
	}
	push @ret, { rightaction => 'addhost'};
	push @ret, { rightaction => 'applyChanges'};
	push @ret, { rightaction => 'cancel'};
	push @ret, { zone => "$reply->{line}" };

	return \@ret;
}

sub addhost
{
	my $this  = shift;
	my $reply = shift;
	my @ret;

	if( exists($reply->{warning})){
		push @ret, {NOTICE => "$reply->{warning}"}
	}

	push @ret, { subtitle => "Create new host" };
	push @ret, { label => main::__('domain_name').": $reply->{zone}" };
	push @ret, { name => 'hostname', value => "$reply->{hostname}", attributes => [ type => 'string',label => 'Relative Domain Name', backlabel => ".$reply->{zone}   (ex.: example.$reply->{zone} , ex-ample.$reply->{zone})" ] };
	push @ret, { name => 'aRecord', value => "$reply->{aRecord}", attributes => [ type => 'string',label => 'aRecord', backlabel => "  ( ex.: 172.16.2.1 )" ] };
	push @ret, { action => 'cancel'};
	push @ret, { name => 'action', value => 'save_host', attributes => [ type => 'action', label => 'apply'] };
	push @ret, { zone => "$reply->{zone}" };

	return \@ret;
}

sub save_host
{
	my $this  = shift;
	my $reply = shift;
	my $hostname = $reply->{hostname};
	my $aRecord = $reply->{aRecord};
	my $wrn_mes = '';

	if( !($hostname =~ /^[a-zA-Z0-9\-]{1,25}$/)){
		$wrn_mes .= main::__("Please don't use special characters while giving the Relativ Domain Name!<br>");
	}

	if( !($aRecord =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) ){
		$wrn_mes .= main::__('Please enter correctly the aRecord!');
	}

	if($wrn_mes ne ''){
		$reply->{warning} = $wrn_mes;
                $this->addhost($reply);
	}else{
		my @hostDNs = $this->add_host("$reply->{hostname}.$reply->{zone}", "$reply->{aRecord}");
		$reply->{line} = $reply->{zone};
		$this->edit_hosts($reply);
	}
}

sub removehost
{
	my $this  = shift;
	my $reply = shift;

	my $host_dn = $reply->{line};
	$this->{LDAP}->delete( $host_dn );

	$reply->{line} = $reply->{subdomain}->{$reply->{line}}->{zone};
	$this->edit_hosts($reply);
}

sub switch_domain_type
{
	my $this  = shift;
	my $reply = shift;

	my $domain_name = $reply->{line};

	my $base = 'zoneName='.$domain_name.','.$this->{SYSCONFIG}->{DNS_BASE};
	my $mesg = $this->{LDAP}->search(  base => $base,
                                        scope => 'base',
                                        attrs => [ 'suseMailDomainType' ],
                                        filter=> "objectclass=*"
                                );

	my $dn;
	my $mtalocal;
	foreach my $e ( $mesg->all_entries ) {
	        $mtalocal = $e->get_value('suseMailDomainType');
		$dn = $e->dn;
	}

	if( $mtalocal eq 'local' ) {
		$this->set_attribute($dn,'suseMailDomainType','virtual');
	} else {
		$this->set_attribute($dn,'suseMailDomainType','local');
	}

	$this->default;
}

sub edit_records
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my $Zone = $reply->{line};

	my $mesg = $this->{LDAP}->search( base    => $this->{SYSCONFIG}->{DNS_BASE},
                                          scope   => 'sub',
                                          attrs   => ['dn'],
					  filter  => '(&(zoneName='.$Zone.')(objectClass=dNSZone)(!(aRecord=*))(!(relativeDomainName=@))(!(objectClass=DHCPEntry)))'
                );
        if( $mesg->code)
        {
                $this->ldap_error($mesg);
                return undef;
        }

	my %records_hash;
	foreach my $entry ($mesg->entries){
		my $entr = $this->get_entry($entry->dn);

		foreach my $attribut (keys %{$entr}){
			if( $attribut !~ /^objectclass|dnsttl|zonename|dnsclass|relativedomainname/ ){
				my $value = $this->get_attribute( $entry->dn, "$attribut");
				$records_hash{$attribut}->{$entry->dn} = $value;
			}
		}
	}

	push @ret, { subtitle => 'Edite Records' };
        push @ret, { label => main::__('domain_name').": $reply->{line}"};

	foreach my $attr (keys %records_hash){
		push @ret, { label => "$attr"};
		my @records = ( 'records' );
		push @records,{ head => [ 'RelativeDomainName', "$attr", 'save', 'delete'] };
		foreach my $rec_dn (keys %{$records_hash{$attr}} ){
				my $rel_dom_name = $this->get_attribute( "$rec_dn", "relativeDomainName");
				push @records,{ line => [ "$rec_dn",
					{ relative_domain_name => "$rel_dom_name" },
					{ name => "$attr", value => "$records_hash{$attr}->{$rec_dn}", attributes => [type =>'string'] },
					{ saverec => main::__('save') },
					{ removerecord => main::__('delete') },
					{ name => 'zone', value => "$Zone", attributes => [ type => 'hidden'] },
                                    ]};
		}
		push @ret, { table => \@records };
	}

        push @ret, { rightaction => 'addrecord'};
	push @ret, { rightaction => 'applyChanges'};
        push @ret, { rightaction => 'cancel'};
        push @ret, { zone => "$reply->{line}" };

	return \@ret;
}

sub addrecord
{
	my $this  = shift;
        my $reply = shift;
        my @ret;

        if( exists($reply->{warning})){
                push @ret, {NOTICE => "$reply->{warning}"}
        }

	my @dns_class = ( 'IN', 'ANY', 'CH', 'HS', '---DEFAULTS---', 'IN');
	my @record_type,
	my $dnszona_schemasubs = get_file("/etc/openldap/schema/dnszone.schema");
	my @file_sch = split("\n",$dnszona_schemasubs);
	foreach my $line (@file_sch){
		if($line =~ /^attributetype(.*)NAME \'(.*)Record\'$/){
			if( ($2 ne 'a') and ($2 ne 'pTR')){
				push @record_type, "$2Record";
			}
		}
	}
	push @record_type, '---DEFAULTS---';
	push @record_type, 'sRVRecord';

	push @ret, { subtitle => "Create new record" };
        push @ret, { label => main::__('domain_name').": $reply->{zone}" };
        push @ret, { name => 'relative_domain_name', value => "$reply->{relative_domain_name}", attributes => [ type => 'string', label => 'Relative Domain Name', , backlabel => "  ( ex.: mailserver ; backup )", size => 50 ] };
	push @ret, { name => 'dns_class', value => \@dns_class, attributes => [ type => 'popup', label => 'dNSClass'] };
	push @ret, { name => 'record_type', value => \@record_type, attributes => [ type => 'popup', label => 'Record Type' ] };
	push @ret, { name => 'record_value', value => "$reply->{record_value}", attributes => [ type => 'string', label => 'Record Value', backlabel => "  ( ex.: 0 100 389 pdc-server )", size => 50 ] };
        push @ret, { action => 'cancel'};
        push @ret, { name => 'action', value => 'save_record', attributes => [ type => 'action', label => 'apply'] };
        push @ret, { zone => "$reply->{zone}" };

        return \@ret;
}

sub save_record
{
	my $this  = shift;
	my $reply = shift;

	my $zone = $reply->{zone};
	my $relative_domain_name = $reply->{relative_domain_name};
	my $dns_class = $reply->{dns_class};
	my $record_type = $reply->{record_type};
        my $record_value = $reply->{record_value};
        my $wrn_mes = '';

        if( !($relative_domain_name =~ /^[_.a-zA-Z0-9\-]{1,50}$/)){
                $wrn_mes .= main::__("Please don't use special characters while giving the Relativ Domain Name!<br>");
        }
        if( !($dns_class =~ /^[a-zA-Z0-9]{1,25}$/) ){
                $wrn_mes .= main::__('Please enter the DNSClass !<br>');
        }
	if($record_type =~ /^aRecord$/i){
		$wrn_mes .= main::__("Domain adding to records is not permitted here. Please use the edit_hosts menu to add the aRecord to the right domain!<br>");
        }

	my $mesg = $this->{LDAP}->search( base    => $this->{SYSCONFIG}->{DNS_BASE},
                                          scope   => 'sub',
                                          attrs   => ['dn'],
                                          filter  => '(&(relativeDomainName='.$relative_domain_name.')(zoneName='.$zone.')(objectClass=dNSZone))'
                );

        if( !$mesg->entries )
        {
	        if($wrn_mes ne ''){
	                $reply->{warning} = $wrn_mes;
	                $this->addrecord($reply);
	        }else{
#			my @recordDNs = $this->add_dns_record(zone, relativedomainname, class, type, value);
			my $recordDNs = $this->add_dns_record( "$zone", "$relative_domain_name", "$dns_class", "$record_type", "$record_value");
#print $recordDNs."  recordDNs\n";
			if($recordDNs eq undef){
				$reply->{warning} = sprintf(main::__("I didn't manage to create a  \"%s\" record (because the record type is missing or type is not real)!"), $record_type );
		                $this->addrecord($reply);
			}else{

		                $reply->{line} = $reply->{zone};
		                $this->edit_records($reply);
			}
	        }	
	}else{
		$reply->{warning} = sprintf(main::__('It already exists in the "%s" the "%s" called domain with this record!'),$zone,$relative_domain_name);
                $this->addrecord($reply);
	}
}

sub removerecord
{
	my $this  = shift;
	my $reply = shift;
	my $record_dn = $reply->{line};

	$this->{LDAP}->delete( $record_dn );

        $reply->{line} = $reply->{records}->{$reply->{line}}->{zone};
        $this->edit_records($reply);
}

sub applyChanges
{
	my $this = shift;
	my $reply = shift;
	$reply->{line} = $reply->{zone};
	$this->rc('named','restart');

	if( exists($reply->{subdomain}) ){
		return $this->edit_hosts($reply);
	}elsif( exists($reply->{records})){
                return $this->edit_records($reply);
	}else{
		return $this->default;
	}
}

sub saverec
{
	my $this  = shift;
	my $reply = shift;

	my $set_rec;
	foreach my $rec_attr (keys %{$reply->{records}->{$reply->{line}}} ){
		if( $rec_attr !~ /^ACTION|APPLICATION|zone|SESSIONID|CATEGORY/){
			$set_rec = $this->set_attribute( $reply->{line}, $rec_attr, $reply->{records}->{$reply->{line}}->{$rec_attr});
		}
	}	


	if($set_rec){
		$reply->{line} = $reply->{records}->{$reply->{line}}->{zone};
		$this->edit_records($reply);
	}else{
		return [ { NOTICE => main::__('Failed to change!')}, ]
	}
}

1;
