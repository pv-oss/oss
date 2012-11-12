# LMD PrinterPriceManagement  modul:
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package PrinterPriceManagement;

use strict;
use oss_base;
use oss_utils;
use DBI;
use DBI qw(:utils);
use vars qw(@ISA);
@ISA = qw(oss_base);
use Data::Dumper;
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
		"printing_price_manager",
		"add_new_printing_price",
		"add_printing_price",
		"del_printing_price",
		"edit_printing_price",
		"save_printing_price",
		"ppm_cancel",
		"invoicing",
		"make_invoice",
		"invoicing_payment",
		"details_invoice",
		"download_invoice",
		"back_to_invoice_list",
		"mark_as_payed",
		"apply",
	];
}

sub getCapabilities
{
	return [
		{ title        => 'PrinterPriceManagement' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ category     => 'User' },
		{ order        => 70 },
		{ variable     => [ "class",                  [ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "workgroup",              [ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "role",                   [ type => "list", size=>"10", multiple=>"true" ] ] },
		{ variable     => [ "users",                  [ type => "list", size=>"15", multiple=>"true" ] ] },
		{ variable     => [ "edit_printing_price",    [ type => "action"] ] },
		{ variable     => [ "del_printing_price",     [ type => "action"] ] },
		{ variable     => [ "details_invoice",        [ type => "action"] ] },
		{ variable     => [ "download_invoice",       [ type => "action"] ] },
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my @filter = ('filter' );
	my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
	my @ret;

	if( -e "/var/adm/oss/invoices_send" ){
		return [
			{ NOTICE => main::__('Please check the page later because the invoice generation and sending is in progress!') },
		]
	}

	if( $this->{LDAP_BASE} ne main::GetSessionValue('sdn') )
        {
                push @ret, { label => main::__( 'Selected School: '). $this->get_attribute(main::GetSessionValue('sdn'),'o') };
        }

	push @ret, { NOTICE => 
#				"<B>".main::__('printing_price_manager').'</B> - '.main::__('Here you can set the print prices of printers.' )."<BR>".
#				"<B>".main::__('invoicing').'</B> - '.main::__('Make a fitering then click "invoicing" to create an invoice for every user having not invoiced printing jobs.')."<BR>".
#				"<B>".main::__('invoicing_payment').'</B> - '.main::__('Make a filtering the click "invoicing_payment" to show and mark paid existing invoices.')
				main::__('Please select filter criteria for processing the Print invoices. The actions Fakturierung and Payment will only be done on the users which mach the filter criteria.')
			};
	if( exists($reply->{warning}) ){
		push @ret, { NOTICE => $reply->{warning} };
	}

	my @filter = ('filter' );
	push @filter, { head => [ 'role', 'class', 'workgroup' ]};
        push @filter, { line => [ 'line',
                                        { role         => $roles },
                                        { class        => $classes },
                                        { workgroup    => $workgroups },
                        ]};

	push @ret, { name   => "*" };
	push @ret, { table  => \@filter };
	push @ret, { action => "printing_price_manager" };
	push @ret, { action => "invoicing" };
	push @ret, { action => "invoicing_payment" };
	return \@ret;
}

sub printing_price_manager
{
	my $this  = shift;
	my @lines = ( 'printers' );
	push @lines, { head => [ 'printer', 'recordtype', 'prices', 'edit', 'delete' ]};

	my $sth = $this->{DBH}-> prepare("SELECT Id, Printer, RecordType, Price FROM PrintingPrice");
	$sth->execute;

	while (my $hashref = $sth -> fetchrow_hashref() ){
		push @lines, { line => [ ${$hashref}{Id},
				{ name => 'printer', value  => ${$hashref}{Printer}, "attributes"=> [ type => "label" ] },
				{ name => 'recordtype', value => main::__("${$hashref}{RecordType}"), "attributes" => [ type => "label" ] },
				{ name => 'price',value => "${$hashref}{Price}".encode("utf8", " €"), "attributes" => [ type => "label" ] },
				{ edit_printing_price => main::__('edit')},
				{ del_printing_price => main::__('delete')}
			]};
	}

	my @ret;
	push @ret, { subtitle => main::__('printing_price_manager') };
	if( scalar(@lines) > 2){
		push @ret, { table  =>  \@lines },
	}else{
		push @ret, { NOTICE => main::__('Please enter the printing prices!')},
	}
	push @ret, { action => 'cancel' };
	push @ret, { action => 'add_new_printing_price' };
	return \@ret;
}

sub add_new_printing_price
{
	my $this  = shift;
	my $reply = shift;
	my $printers     = $this->get_printers();
	my @printername  = ();

	my @printers_sql;
	my $sth = $this->{DBH}-> prepare("SELECT * FROM PrintingPrice");
        $sth->execute;
        while (my $hashref = $sth->fetchrow_hashref() ){
		push @printers_sql, ${$hashref}{Printer};
        }

	foreach my $printer_sql (@printers_sql){
		delete $printers->{$printer_sql};
	}

	foreach my $pn (sort (keys %{$printers})) {
		push @printername, $pn;
	}

	my @ret;
	if( exists($reply->{warning}) ){
		push @ret, { NOTICE => $reply->{warning} };
	}
	push @ret, { subtitle => main::__('add_new_printing_price') };
	push @ret, { label => main::__('Please add the following configuration parameters:') };
	push @ret, { name => 'printer', value => [ @printername, '---DEFAULTS---', "$reply->{printer}" ], attributes => [ type => 'popup'] };
	push @ret, { name => 'recordtype', value => [ ['Page', main::__('Page')], ['Job', main::__('Job')], '---DEFAULTS---', "$reply->{recordtype}"], attributes => [ type => 'popup'] };
	push @ret, { name => 'price', value => "$reply->{price}", attributes => [ type => 'string', backlabel => encode("utf8","€")] };
	push @ret, { action => 'ppm_cancel' };
	push @ret, { action => 'add_printing_price' };
	return \@ret;
}

sub add_printing_price
{
	my $this  = shift;
	my $reply = shift;
	my $msg   = '';
	if( !$reply->{printer} ){
		$msg .= main::__('Please select printer!').'<BR>';
	}
	if( !$reply->{recordtype} ){
		$msg .= main::__('Please select the printing invoicing type (either by pages or by jobs)!').'<BR>';
	}
	if( !$reply->{price} or ($reply->{price} !~ /[0-9\.]{1,5}/) ){
		$msg .= main::__('Please assign a correct price for the invoice type!').'<BR>';
	}
	if( $msg ){
		$reply->{warning} = $msg;
		return $this->add_new_printing_price($reply);
	}

	my $sth   = $this->{DBH}->prepare("INSERT INTO PrintingPrice (Id, Printer, RecordType, Price) VALUES (NULL, '$reply->{printer}', '$reply->{recordtype}', '$reply->{price}')");
	$sth->execute;
	$this->printing_price_manager();
}

sub del_printing_price
{
	my $this  = shift;
	my $reply = shift;
	my $sth   = $this->{DBH}->prepare("DELETE FROM PrintingPrice WHERE Id=$reply->{line}");
	$sth->execute;
	$this->printing_price_manager();
}

sub edit_printing_price
{
	my $this  = shift;
	my $reply = shift;
	my $sth   = $this->{DBH}->prepare("SELECT Id, Printer, RecordType, Price FROM PrintingPrice WHERE Id = $reply->{line}");
	$sth->execute;
	my $hashref = $sth->fetchrow_hashref();

	my @ret;
	if( exists($reply->{warning}) ){
		push @ret, { NOTICE => $reply->{warning} };
	}
	push @ret, { subtitle => 'edit' };
	push @ret, { label => main::__('Please add the following configuration parameters:') };
	push @ret, { name => 'printer', value => ${$hashref}{Printer} || $reply->{printer_h} , "attributes" => [type => "label"]};
	push @ret, { name => 'recordtype', value => [ ['Page', main::__('Page')], ['Job', main::__('Job')], '---DEFAULTS---', ${$hashref}{RecordType} ], attributes => [ type => 'popup']};
	push @ret, { name => 'price', value => ${$hashref}{Price}, attributes => [ type => 'string', backlabel => encode("utf8","€")]};
	push @ret, { name => 'id', value => ${$hashref}{Id}, attributes => [ type => 'hidden' ] };
	push @ret, { name => 'printer_h', value => ${$hashref}{Printer} , "attributes" => [type => "hidden"]};
	push @ret, { action => 'ppm_cancel' };
	push @ret, { action => 'save_printing_price' };
	return \@ret;
}

sub save_printing_price
{
	my $this  = shift;
	my $reply = shift;
        if( !$reply->{price} or ($reply->{price} !~ /[0-9\.]{1,5}/) ){
                $reply->{warning} = main::__('Please assign a correct price for the invoice type!').'<BR>';
		return $this->edit_printing_price($reply);
        }
	my $sth   = $this->{DBH}->prepare("UPDATE PrintingPrice SET RecordType='$reply->{recordtype}', Price='$reply->{price}' WHERE Id=$reply->{id}");
	$sth->execute;
	$this->printing_price_manager();
}

sub ppm_cancel
{
	my $this  = shift;
	my $reply = shift;
	$this->printing_price_manager();
}

sub invoicing
{
	my $this  = shift;
	my $reply = shift;
	my $name  = $reply->{name} || '*';
	my @role  = split /\n/, $reply->{filter}->{line}->{role}  || ();
	my @group = split /\n/, $reply->{filter}->{line}->{workgroup} || ();
	my @class = split /\n/, $reply->{filter}->{line}->{class} || ();

	my $user  = $this->search_users($name,\@class,\@group,\@role);
	my @users = ();
	my @users_tmp = ();
	foreach my $dn ( sort keys %{$user} ){
		push @users , [ $dn, $user->{$dn}->{uid}->[0].' '.$user->{$dn}->{cn}->[0].' ('.$user->{$dn}->{description}->[0].')' ];
		push @users_tmp, $dn;
	}

	my $printers = $this->get_printers();
	my @printername;
	foreach my $pn (sort (keys %{$printers})) {
		push @printername, $pn;
	}

	my @notifications_forms = ('notifications_forms' );
	push @notifications_forms, { head => [ ]};
	push @notifications_forms, { line => [ '1',
				{ name => 'via_email_l', value => main::__('via_email_l'), attributes => [ type => 'label']},
				{ name => 'via_email', value => "0", attributes => [ type => 'boolean', help => main::__('If we select this option users who have unpaid invoices will be notified via email.')]}
	]};
	push @notifications_forms, { line => [ '2',
				{ name => 'in_home_directory_l', value => main::__('in_home_directory_l'), attributes => [ type => 'label']},
				{ name => 'in_home_directory', value => "0", attributes => [ type => 'boolean', help => main::__('If we select this option then the users with unpaid invoices will have these invoices placed in their home library.')]}
		]};
	push @notifications_forms, { line => [ '3',
				{ name => 'print_label', value => main::__('print_l'), attributes => [ type => 'label']},
				{ name => 'printer', value => \@printername, attributes => [ type => 'popup', help => main::__('If we select a printer then on the selected printer we print the selected users unpaid invoices.')]},
		]};

	my @ret;
	push @ret, { subtitle => main::__('invoicing') };
	push @ret, { NOTICE =>  main::__("Please select from the list those users who you wish to create their printing invoices!").'<BR>'.
				main::__("Select if the invoice should be emailed, placed in the home library or printed out now!").'<BR>'.
				main::__("If you do not select anything only the users then the invoicing will happen only!") 
				};
	push @ret, { users => [ @users, '---DEFAULTS---', @users_tmp ] };
	push @ret, { label => main::__('notifications_form') };
	push @ret, { table => \@notifications_forms };
	push @ret, { action => "cancel" };
	push @ret, { action => "make_invoice" };
	return \@ret;
}

sub make_invoice
{
	my $this    = shift;
	my $reply   = shift;
	my $mesages = '';
	my @select_users = split /\n/, $reply->{users};

	my $printing_price    = $this->get_printing_price(); #get printing price
	my $users_invoic_hash = $this->create_users_invoic_hash(\@select_users, $printing_price ); #calc_invocies
	if( exists( $users_invoic_hash->{bad_printer_price}) ){
		my @bad_printer_price = ();
		foreach my $prn ( keys %{$users_invoic_hash->{bad_printer_price}}){
			push @bad_printer_price, $prn;
		}
		$mesages .= main::__("For the following printers there is no printer pricing set, these printings are not invoiced and they don't show up In the report : ").'<BR>'.join("; ",@bad_printer_price).'<BR><BR>';
	}
	delete( $users_invoic_hash->{bad_printer_price} );

	my $us = $this->save_invoices_in_to_database($users_invoic_hash); #insert invoices in to database
	if( exists($us->{good}) ){
		my $users = '';
		foreach my $user ( keys %{$us->{good}}){
			$users .= "$user, ";
		}
		$mesages .= main::__('The invoice has been generated for the users (starting from the last invoicing date until today):').'<BR>'.$users.'<BR><BR>';
	}else{
		$mesages .= main::__('The filtered users have their printing invoiced or they have not printed since the last invoicing time or the selected printer does not have a set printing price!').'<BR><BR>';
	}

	my $users_notif = $this->requesting_users_who_need_notification(\@select_users);

	#make: vi mail, in home directory, print
	my $cmd = '';
	if( $reply->{notifications_forms}->{1}->{via_email} ){
		$cmd .= " --via_email";
	}
	if( $reply->{notifications_forms}->{2}->{in_home_directory} ){
		$cmd .= " --in_home_directory";
	}
	if( $reply->{notifications_forms}->{3}->{printer} ){
		$cmd .= " --printer=$reply->{notifications_forms}->{3}->{printer}";
	}
	if( $cmd ne ''){
		if( scalar(@$users_notif) ){
			my $act_user_dn = main::GetSessionValue('dn');
			my $act_user_lang = main::GetSessionValue('lang');
			$cmd .= " --act_user_dn=$act_user_dn";
			my $users = join(",",@$users_notif);
#			print "/usr/share/oss/tools/send_invoices.pl $cmd --users=$users --lang=$act_user_lang"; exit;
			system("/usr/share/oss/tools/send_invoices.pl $cmd --users=$users --lang=$act_user_lang &");
			$mesages .=     main::__("The printing invoices are either sent by mail or it will be placed in the user's home library or print depending on the choice made in the notifications form.").
					main::__('Depending if the user has unpaid invoices, if not then they would not get any notifications.').'<BR>'.
					main::__('users').' : '.join("; ",@$users_notif).'<BR><BR>';
		}

		return [
			{ NOTICE => $mesages },
			{ action => 'cancel' },
		]
	}

	return [
		{ NOTICE => $mesages },
		{ action => 'cancel' },
	]
}

sub invoicing_payment
{
	my $this = shift;
	my $reply = shift;
	my $name  = $reply->{name} || '*';
	my @role  = split /\n/, $reply->{filter}->{line}->{role}  || ();
	my @group = split /\n/, $reply->{filter}->{line}->{workgroup} || ();
	my @class = split /\n/, $reply->{filter}->{line}->{class} || ();

	my $where = '';
	if( !exists($reply->{where}) ){
		my $user  = $this->search_users($name,\@class,\@group,\@role);
		if( scalar(@role) or scalar(@group) or scalar(@class) or ($name ne '*') ){
			$where .= ' WHERE ( ';
			foreach my $dn ( sort keys %{$user} ){
				$where .= ' or ';
				print $user->{$dn}->{uid}->[0]."\n";
				$where .= "User='$user->{$dn}->{uid}->[0]'";
			}
			$where .= ' )';
			$where =~ s/ or //;
		}
	}
	else
	{
		$where = $reply->{where};
	}

	my $sth = $this->{DBH}->prepare("SELECT Id, InvoiceNumber, User, DateOfPayment, PaymentSum FROM PrintingPayment $where");
	$sth->execute;

	my @invoicing_payment = ( 'invoicing_payment' );
	push @invoicing_payment, { head => [ 'invoice_number', 'user', 'payment_date', 'summary', 'invoice_paying' ] };
	while (my $hashref = $sth->fetchrow_hashref() ){
		my $invoice_paying = 1;
		if( ${$hashref}{DateOfPayment} eq '0000-00-00 00:00:00' ){$invoice_paying = '0'; ${$hashref}{DateOfPayment} = ''}
		push @invoicing_payment, { line => [ "${$hashref}{Id}",
						{ name => 'invoce_number', value => ${$hashref}{InvoiceNumber}, attributes => [ type => 'label'] },
						{ name => 'user', value => ${$hashref}{User}, attributes => [ type => 'label'] },
						{ name => 'payment_date', value => ${$hashref}{DateOfPayment}, attributes => [ type => 'label'] },
						{ name => 'summary', value => ${$hashref}{PaymentSum}, attributes => [ type => 'label'] },
						{ name => 'invoice_paying', value => $invoice_paying, attributes => [ type => 'boolean'] },
						{ name => 'user_h', value => ${$hashref}{User}, attributes => [ type => 'hidden'] },
						{ name => 'payment_date_h', value => ${$hashref}{DateOfPayment}, attributes => [ type => 'hidden'] },
						{ name => 'summary_h', value => ${$hashref}{PaymentSum}, attributes => [ type => 'hidden'] },
						{ name => 'where', value => $where, attributes => [ type => 'hidden'] },
						{ details_invoice => main::__('details_invoice') },
						{ download_invoice => main::__('download_invoice') },
			]};
	}

	my @ret;
	push @ret, { subtitle => main::__('invoicing_payment') };
	push @ret, { action => 'cancel' };
	if( scalar(@invoicing_payment) < 3 ){
		push @ret, { NOTICE => main::__('No Invoices Due Payment!') };
	}else{
		push @ret, { table  => \@invoicing_payment };
		push @ret, { action => 'apply' };
	}
	push @ret, { name => 'name_h', value => "$reply->{filter}->{line}->{name}", attributes => [ type => 'hidden' ] };
	push @ret, { name => 'role_h', value => "$reply->{filter}->{line}->{role}", attributes => [ type => 'hidden' ] };
	push @ret, { name => 'class_h', value => "$reply->{filter}->{line}->{class}", attributes => [ type => 'hidden' ] };
	push @ret, { name => 'workgroup_h', value => "$reply->{workgroup}", attributes => [ type => 'hidden' ] };
	return \@ret;
}

sub apply
{
	my $this  = shift;
	my $reply = shift;
	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	my $DateOfPayment = sprintf('%4d-%02d-%02d %02d:%02d:%02d',$year+1900,$mon+1,$mday,$hour,$min,$sec);
	foreach my $line ( keys %{$reply->{invoicing_payment}} ){
		if( ($reply->{invoicing_payment}->{$line}->{invoice_paying}) and !($reply->{invoicing_payment}->{$line}->{payment_date_h}) ){
			my $sth = $this->{DBH}->prepare("UPDATE PrintingPayment SET DateOfPayment='$DateOfPayment' WHERE Id='$line' ");
			$sth->execute;
		}elsif( !($reply->{invoicing_payment}->{$line}->{invoice_paying}) and ($reply->{invoicing_payment}->{$line}->{payment_date_h}) ){
			my $sth = $this->{DBH}->prepare("UPDATE PrintingPayment SET DateOfPayment='0000-00-00 00:00:00' WHERE Id='$line' ");
			$sth->execute;
		}
	}
	$reply->{name} = $reply->{name_h}; delete($reply->{name_h});
	$reply->{filter}->{line}->{role} = $reply->{role_h}; delete($reply->{role_h});
	$reply->{filter}->{line}->{class} = $reply->{class_h}; delete($reply->{class_h});
	$reply->{filter}->{line}->{workgroup} = $reply->{workgroup_h}; delete($reply->{workgroup_h});
	return $this->invoicing_payment($reply);
}

sub details_invoice
{
	my $this  = shift;
	my $reply = shift;
	my $sth = $this->{DBH}->prepare("SELECT * FROM PrintingLog WHERE PaymentId='$reply->{line}'");
	$sth->execute;

	my @paiddetails = ( 'details' );
	while (my $hashref = $sth->fetchrow_hashref() ){
		push @paiddetails, { line => [ 'sum',
					{ name => 'printer', value => ${$hashref}{Printer}, attributes => [ type => 'label'] },
					{ name => 'printing_datetime', value => ${$hashref}{DateTime}, attributes => [ type => 'label'] },
					{ name => 'page_number', value => ${$hashref}{PageNumber}, attributes => [ type => 'label'] },
					{ name => 'num_copies', value => ${$hashref}{NumCopies}, attributes => [ type => 'label'] },
					{ name => 'recordtype', value => ${$hashref}{RecordType}, attributes => [ type => 'label'] },
					{ name => 'price', value => ${$hashref}{Price}, attributes => [ type => 'label'] },
			]};
	}

	$sth = $this->{DBH}->prepare("SELECT * FROM PrintingPayment WHERE Id='$reply->{line}'");
	$sth->execute;
	my $hashref = $sth->fetchrow_hashref();

	my @ret;
	push @ret, { subtitle  => sprintf(main::__('%s User is Printing Invoice'), ${$hashref}{User} ) };
	push @ret, { label  => main::__('Invoice Content :') };
	push @ret, { name => 'user', value => "${$hashref}{User}", attributes => [ type => 'label' ] };
	if( ${$hashref}{DateOfPayment} eq "0000-00-00 00:00:00" ){
		push @ret, { name => 'date_of_payment', value => main::__('No Payment Made!'), attributes => [ type => 'label' ] };
	}else{
		push @ret, { name => 'date_of_payment', value => "${$hashref}{DateOfPayment}", attributes => [ type => 'label' ] };
	}
	push @ret, { name => 'summary', value => "${$hashref}{PaymentSum}", attributes => [ type => 'label' ] };
	push @ret, { label  => main::__('Related Printing Related To Invoice :') };
	push @ret, { table  => \@paiddetails };
	push @ret, { name => 'where', value => $reply->{invoicing_payment}->{$reply->{line}}->{where}, attributes => [ type => 'hidden'] };
	push @ret, { name => 'printing_payment_id', value => $reply->{line}, attributes => [ type => 'hidden'] };
	push @ret, { rightaction => 'mark_as_payed' };
	push @ret, { rightaction => 'back_to_invoice_list' };
	return \@ret;
}

sub mark_as_payed
{
	my $this  = shift;
	my $reply = shift;
	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
        my $DateOfPayment = sprintf('%4d-%02d-%02d %02d:%02d:%02d',$year+1900,$mon+1,$mday,$hour,$min,$sec);
	my $sth = $this->{DBH}->prepare("UPDATE PrintingPayment SET DateOfPayment='$DateOfPayment' WHERE Id='$reply->{printing_payment_id}' ");
	$sth->execute;
	$reply->{line} = $reply->{printing_payment_id};
	$this->details_invoice($reply);
}
sub back_to_invoice_list
{
	my $this  = shift;
	my $reply = shift;
	$this->invoicing_payment($reply);
}

sub download_invoice
{
	my $this  = shift;
	my $reply = shift;
	my $report_url = "/usr/share/lmd/tools/JavaBirt/Reports/PrinterPriceManagement.rptdesign";
	my ($db_password) = parse_file('/root/.my.cnf',"password=");

	my $cmd = "java -jar /usr/share/lmd/tools/JavaBirt/JavaBirt.jar REPORT_URL=$report_url COMMAND=EXECUTE OUTPUT=pdf #DB_DRIVERCLASS=com.mysql.jdbc.Driver #DB_URL=jdbc:mysql://localhost/lmd #DB_USER=root #DB_PWD=$db_password PAYMENT_ID=$reply->{line}";
	my $result = cmd_pipe("$cmd");

	if($result){
		return [
			{ NOTICE => "$result" }
		]
	}

	$report_url =~ s/rptdesign/pdf/;
	my $mime = `file -b --mime-type '$report_url'`;  chomp $mime;
	my $tmp  = `mktemp /tmp/ossXXXXXXXX`;    chomp $tmp ;
	system("/usr/bin/base64 -w 0 '".$report_url."' > $tmp ");
	my $content = get_file($tmp);
	my $sth = $this->{DBH}->prepare("SELECT * FROM PrintingPayment WHERE Id='$reply->{line}' ");
	$sth->execute;
	my $hashref = $sth->fetchrow_hashref();
	${$hashref}{DateOfPayment} =~ s/ |:|-/_/g;
	my $name    = main::__("invoice")."_${$hashref}{DateOfPayment}.pdf";
	
	return [
		{ name=> 'download' , value=>$content, attributes => [ type => 'download', filename=>$name, mimetype=>$mime ] }
	];
}

#-----------local subrutine ---------------

sub get_printing_price
{
	my $this = shift;
	my %PrinterPrice = ();
	my $sth = $this->{DBH}->prepare("SELECT Id, Printer, RecordType, Price FROM PrintingPrice");
	$sth->execute();
	while (my $hashref = $sth->fetchrow_hashref() ){
		$PrinterPrice{${$hashref}{Printer}}->{${$hashref}{RecordType}} = ${$hashref}{Price};
	}
	return \%PrinterPrice;
}

sub create_users_invoic_hash
{
	my $this  = shift;
	my $select_users = shift;
	my $printing_price = shift;
	my %hash;

	foreach my $dn ( @$select_users ){
		my $user_uid = $this->get_attribute($dn,'uid');
		my $sth = $this->{DBH}->prepare("SELECT Id, Printer, User, PageNumber, DateTime, NumCopies FROM PrintingLog WHERE User='$user_uid' and PaymentId=0 and Price=0");
		$sth->execute;
		while (my $hashref = $sth->fetchrow_hashref() ){
			$hash{${$hashref}{User}}->{${$hashref}{Id}}->{Printer}  = ${$hashref}{Printer};
			$hash{${$hashref}{User}}->{${$hashref}{Id}}->{DateTime} = ${$hashref}{DateTime};
			if( exists($printing_price->{${$hashref}{Printer}}->{Page}) ){
				$hash{${$hashref}{User}}->{${$hashref}{Id}}->{Price} = ($printing_price->{${$hashref}{Printer}}->{Page} * ${$hashref}{PageNumber}) * ${$hashref}{NumCopies};
				$hash{${$hashref}{User}}->{${$hashref}{Id}}->{RecordType} = 'Page';
			}elsif( exists($printing_price->{${$hashref}{Printer}}->{Job}) ){
				$hash{${$hashref}{User}}->{${$hashref}{Id}}->{Price} = ($printing_price->{${$hashref}{Printer}}->{Job} * 1) * ${$hashref}{NumCopies};
				$hash{${$hashref}{User}}->{${$hashref}{Id}}->{RecordType} = 'Job';
			}else{
				$hash{bad_printer_price}->{${$hashref}{Printer}} = 0;
			}
		}

		my $sth2 = $this->{DBH}->prepare("SELECT Id, UserUID  FROM UsersData WHERE UserUID='$user_uid' ");
		$sth2->execute;
		my $hashref = $sth2->fetchrow_hashref();
		my $attributes = $this->get_attributes( "$dn",['displayName', 'telephoneNumber', 'l', 'postalCode', 'st', 'street' ] );
		if( !${$hashref}{UserUID} ){
			my $attributes = $this->get_attributes( "$dn",['displayName', 'telephoneNumber', 'mobile', 'homePhone', 'l', 'postalCode', 'st', 'street' ] );
			my $sth3 = $this->{DBH}->prepare("INSERT INTO UsersData (Id, UserUID, UserName, Telaphone, Location, PostalCode, Street ) VALUES(NULL, '$user_uid', '$attributes->{displayName}->[0]', '$attributes->{telephoneNumber}->[0]', '$attributes->{l}->[0]', '$attributes->{postalCode}->[0]', '$attributes->{street}->[0]' )");
			$sth3->execute;
		}
		else
		{
			my $sth3 = $this->{DBH}->prepare("UPDATE UsersData SET Telaphone='$attributes->{telephoneNumber}->[0]', Location='$attributes->{l}->[0]', PostalCode='$attributes->{postalCode}->[0]', Street='$attributes->{street}->[0]' WHERE UserUID='$user_uid' ");
			$sth3->execute;
		}
	}
	return \%hash;
}

sub save_invoices_in_to_database
{
	my $this = shift;
	my $users_invoic_hash = shift;
	my %us;

	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	foreach my $user ( keys %{$users_invoic_hash}){
		my $sum = 0;
		foreach my $printer_id ( keys %{$users_invoic_hash->{$user}}){
			if( exists( $users_invoic_hash->{$user}->{$printer_id}->{Price} ) ){
				$sum += $users_invoic_hash->{$user}->{$printer_id}->{Price};
			}
		}
		if( $sum ne 0 ){
			my $sth = $this->{DBH}->prepare("INSERT INTO PrintingPayment (Id, User, DateOfPayment, PaymentSum ) VALUES(NULL, '$user', '', '$sum')");
			$sth->execute;
			my $last_printing_payment_id = $this->{DBH}->last_insert_id(undef, undef, qw(PrintingPayment some_table_id));

			my $base_invoice_num = sprintf('%4d%02d%02d',$year+1900,$mon+1,$mday);
			$base_invoice_num .= sprintf('%06d',$last_printing_payment_id);
			$sth = $this->{DBH}->prepare("UPDATE PrintingPayment SET InvoiceNumber='$base_invoice_num' WHERE Id='$last_printing_payment_id'");
			$sth->execute;

			foreach my $printer_id ( keys %{$users_invoic_hash->{$user}}){
				if( exists( $users_invoic_hash->{$user}->{$printer_id}->{Price} ) ){
					my $sth1 = $this->{DBH}->prepare("UPDATE PrintingLog SET RecordType='$users_invoic_hash->{$user}->{$printer_id}->{RecordType}', PaymentId='$last_printing_payment_id', Price='$users_invoic_hash->{$user}->{$printer_id}->{Price}' WHERE Id='$printer_id' ");
					$sth1->execute;
				}
			}
			$us{good}->{$user} = 1;
		}
	}
	return \%us;
}

sub requesting_users_who_need_notification
{
	my $this = shift;
	my $select_users = shift;

	my $where .= ' and ( ';
	foreach my $user_dn ( sort @$select_users ){
		$where .= ' or ';
		my $user_uid = $this->get_attribute($user_dn,'uid');
		$where .= "User='$user_uid'";
	}
	$where .= ' )';
	$where =~ s/ or //;

	my $sth = $this->{DBH}->prepare("SELECT Id, InvoiceNumber, User, DateOfPayment, PaymentSum FROM PrintingPayment WHERE DateOfPayment='0000-00-00 00:00:00' $where");
	$sth->execute;
	my @users_notif = ();
	while (my $hashref = $sth->fetchrow_hashref() ){
		push @users_notif, ${$hashref}{User};
	}
	return \@users_notif;
}

1;
