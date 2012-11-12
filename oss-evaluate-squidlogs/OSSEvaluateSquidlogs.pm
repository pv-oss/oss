# LMD OSSEvaluateSquidlogs modul
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package OSSEvaluateSquidlogs;

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
		"apply",
		"details",
		"no_details",
		"delete",
		"next",
		"back",
	];
}

sub getCapabilities
{
        return [
                 { title        => 'EvaluateSquidlogs' },
                 { type         => 'command' },
                 { allowedRole  => 'root' },
                 { allowedRole  => 'sysadmins' },
                 { category     => 'Proxy' },
                 { order        => 2 },
                 { variable     => [ "convert_ip",        [ type => "boolean" ] ] },
                 { variable     => [ "from",              [ type => "date" ] ] },
                 { variable     => [ "to",                [ type => "date" ] ] },
		 { variable     => [ "details",           [ type => "popup" ] ] },
		 { variable     => [ "log_file_name",     [ type => 'label'] ] },
		 { variable     => [ "log_file_date",     [ type => 'label'] ] },
		 { variable     => [ "details",           [ type => 'action'] ] },
		 { variable     => [ "no_details",        [ type => 'action'] ] },
		 { variable     => [ "delete",            [ type => 'action'] ] },
		 { variable     => [ "date",              [ type => 'label'] ] },
		 { variable     => [ "time",              [ type => 'label'] ] },
		 { variable     => [ "user",              [ type => 'label'] ] },
		 { variable     => [ "host",              [ type => 'label'] ] },
		 { variable     => [ "path_file",         [ type => 'hidden'] ] },
		 { variable     => [ "pg_limit",          [ type => 'hidden'] ] },
        ];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my $sysadmin_user = main::GetSessionValue('username');

	if( exists($reply->{warning}) ){
		push @ret, { NOTICE  => "$reply->{warning}" };
	}

	my @lines = ('squid_log');
	foreach my $f (sort(glob "/home/sysadmins/$sysadmin_user/squid-log-evaluate.*") )
	{
		$f =~ /squid-log-evaluate.(.*)-[0-9]{0,4}$/;
		my $y = substr("$1", 0, 4);
		my $m = substr("$1", 4, 2);
		my $d = substr("$1", 6, 2);
		my $date = $y."-".$m."-".$d;
		my @file_name = split("/", $f);

		my $file_data = `cat $f`;
		if( !$file_data and ($f =~ /squid-log-evaluate.(.*)-[0-9]{0,4}.err$/)){
			system("rm $f");
			next;
		}
		my ($filter, @tmp) = split ("\n",$file_data);
		my @filter_param = split(" ",$filter);
		$filter_param[3] = substr($filter_param[3], 0, 4)."-".substr($filter_param[3], 4, 2)."-".substr($filter_param[3], 6, 2);
		$filter_param[4] = substr($filter_param[4], 0, 4)."-".substr($filter_param[4], 4, 2)."-".substr($filter_param[4], 6, 2);
		if($filter_param[6]){ $filter_param[6] = 'No' }else{ $filter_param[6] = 'Yes' }
		my $filter_par = main::__('uid')."=$filter_param[1], ".main::__('url')."=$filter_param[2], ".main::__('from')."=$filter_param[3], ".main::__('to')."=$filter_param[4], ".main::__('ws')."=$filter_param[5], ".main::__('convert_ip')."=$filter_param[6]";

		push @lines, { line => [ $f,
						{ name => 'log_file_name', value => "$file_name[4]", attributes => [type => 'label', help => "$filter_par" ] },
						{ log_file_date => "$date" },
						{ details       => main::__("Details") },
						{ no_details    => main::__("No Details") },
						{ delete        => main::__("delete") },
				]};

	}

	if( scalar(@lines) > 1 ){
		push @ret, { label => "Last evaluation" };
		push @ret, { table => \@lines };
	}
	my $date = `date +\%Y-\%m-\%d`; chomp $date;
	push @ret, { label       => "New order for evaluation" };
	push @ret, { uid         => '*' };
	push @ret, { url         => '*' };
	push @ret, { from        => "$date" };
	push @ret, { to          => "$date" };
	push @ret, { workstation => '*' };
	push @ret, { convert_ip  =>  0 };
	push @ret, { action      => 'cancel' };
	push @ret, { action      => 'apply' };

	return \@ret;
}


sub apply
{
	my $this  = shift;
	my $reply = shift;
	my $atts  = ' --uid='.$reply->{'uid'}.' --from='.$reply->{'from'}.' --to='.$reply->{'to'}.' --url='.$reply->{'url'}.' --ws='.$reply->{'workstation'};
	if( ! $reply->{'convert_ip'} )
	{
	   $atts .= " --IP"
	}
	my $date = `date +\%Y\%m\%d-\%H\%M`; chomp $date;
	$atts .= ' --o=/home/sysadmins/admin/squid-log-evaluate.'.$date;
	system("/usr/sbin/oss_evaluate_squid_logs.pl $atts &");
	return {
		TYPE    => 'NOTICE',
		MESSAGE => 'Evaluating squid log files was started. You can find the result in /home/sysadmins/admin/squid-log-evaluate-DATE'
	};
#	$reply->{warning} = sprintf( main::__('Evaluating squid log files was started. You can find the result in /home/sysadmins/admin/squid-log-evaluate-%s'), $date);
#	$this->default($reply);
}

sub no_details
{
	my $this      = shift;
	my $reply     = shift;
        my $path_file = $reply->{line};
	my $SESSIONID = $reply->{squid_log}->{$reply->{line}}->{SESSIONID};

	if($path_file =~ /(.*).err/){
                my $file_error = `cat $path_file`;
                return [
                         { NOTICE  => main::__("Error file :")." \"$path_file\".<BR>".main::__("File content :")."<BR>$file_error" },
                        ];
        }

	my $file = $this->split_file("$path_file", "$SESSIONID");
	$reply->{line} = $file;
        $this->details($reply);
}

sub details
{
        my $this      = shift;
	my $reply     = shift;
	my $path_file = $reply->{line};
	my $pg_num    = $reply->{pg_num} || 0;
	my $pg_limit  = $reply->{pg_limit} || 20;
	my @lines     = ('details');
	my $pg_init   = 0;

	if($path_file =~ /(.*).err/){
		my $file_error = `cat $path_file`;
		return [
			 { NOTICE  => main::__("Error file :")." \"$path_file\".<BR>".main::__("File content :")."<BR>$file_error" },
			];
	}

	open(IN,"$path_file");
	while(<IN>){
		if( $_ =~ /^filter:/){next}
		if( $pg_init == $pg_limit){
			last;
		}elsif( $pg_init < $pg_num ){
			$pg_init++;
			next;
		}else{
			my ($date, $time, $user, $host, $url) = split(' ',$_);
			my $dat = substr($date,0,4);
			my $mon = substr($date,4,2);
			my $day = substr($date,6,2);
			push @lines, { line => [ $date."_".$time,
							{ date => "$dat-$mon-$day" },
							{ time => "$time" },
							{ user => "$user" },
							{ host => "$host" },
							{ name => "url", value => "$url", attributes => [ type => "label" ] },
					]};
			$pg_init++;
		}
	}
	close(IN);

	if(scalar(@lines) < 2 ){
#		return [ { NOTICE => main::__("empty_squid_log_file") }, ];
		push @lines, { head => [ 'date', 'time', 'user', 'host', 'name' ]};
		return [
			 { table     => \@lines },
			 { action    => 'cancel' },
		];
	}elsif(($pg_init < $pg_limit) and ($pg_init > $pg_num) and !$pg_num){
		return [
			 { table => \@lines },
		];
	}elsif(!$pg_num){
		return [
			 { table     => \@lines },
			 { action    => 'cancel' },
			 { action    => 'next' },
			 { path_file => "$path_file" },
			 { pg_limit  => "$pg_limit" },
		];
	}elsif( ($pg_init < $pg_limit) and ($pg_init > $pg_num)  ){
		return [
			 { table     => \@lines },
			 { action    => 'back' },
			 { action    => 'cancel' },
			 { path_file => "$path_file" },
			 { pg_limit  => "$pg_limit" },
			];
	}else{
		return [
			 { table     => \@lines },
			 { action    => 'back' },
			 { action    => 'cancel' },
			 { action    => 'next' },
			 { path_file => "$path_file" },
			 { pg_limit  => "$pg_limit" },
			];
	}
}

sub delete
{
	my $this      = shift;
	my $reply     = shift;
	my $path_file = $reply->{line};

        my $username = main::GetSessionValue('username');
        my $tmp_file_path = "/tmp/tmp_squid_log_".$username."_";
	foreach ( glob("$tmp_file_path*") ){
		system("rm $_");
	}
	system("rm $path_file");
	$this->default();
}

sub next
{
	my $this  = shift;
	my $reply = shift;

	$reply->{line}     = $reply->{path_file};
	$reply->{pg_num}   = $reply->{pg_limit};
	$reply->{pg_limit} = $reply->{pg_num} + 20;
	$this->details($reply);
}

sub back
{
	my $this = shift;
	my $reply = shift;

	$reply->{line}     = $reply->{path_file};
	$reply->{pg_num}   = $reply->{pg_limit} - 40;
	$reply->{pg_limit} = $reply->{pg_limit} - 20;
	$this->details($reply);
}

sub split_file
{
        my $this      = shift;
        my $path_file = shift;
	my $SESSIONID = shift;
	my $username = main::GetSessionValue('username');
	$SESSIONID = $username."_".$SESSIONID;

	system("/usr/share/oss/tools/make_squid_log_tmp.pl --path=$path_file --sessid=$SESSIONID &");
	sleep 1;
	return "/tmp/tmp_squid_log_$SESSIONID";
}

1;
