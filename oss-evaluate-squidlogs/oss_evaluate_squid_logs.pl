#!/usr/bin/perl
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use Getopt::Long;
use oss_utils;
use oss_base;
use Data::Dumper;

my %options    = ();
my $over       = 0;
my $result = GetOptions(\%options,
                        "help",
                        "IP",
                        "uid=s",
                        "url=s",
                        "ws=s",
                        "from=s",
                        "to=s",
                        "o=s"
                        );

if (!$result && ($#ARGV != -1))
{
        usage();
        exit 1;
}

if( defined($options{'help'}) )
{
        usage();
	exit 0;
}
if( !scalar(keys(%options)))
{
        usage();
	exit 1;
}

sub usage
{
    print "\n  oss_eval_squid.pl --o=<OutPut File> --uid=<uid> --url=<URL> --from=<YYYYMMDD> --to=<YYYYMMDD> --ws=<workstation> --IP\n\n".
"       You have to define at last one of the parameter!\n\n".
"       --o     Print output in this file?\n".
"       --uid   Who are you looking for?\n".
"       --url   What URL are you looking for?\n".
"       --from  From which date are you looking for?\n".
"       --to    Until which date are you looking for?\n".
"       --ws    The workstation of interess?\n".
"       --IP    Do not convert IP-address in host name. This saves a lot of time!\n\n";
}

my $oss = oss_base->new();

system("test -e /tmp/acces && rm /tmp/acces");

$options{'uid'}  = '.*'      if( !defined($options{'uid'}) || $options{'uid'} eq '*' );
$options{'url'}  = '.*'      if( !defined($options{'url'}) || $options{'url'} eq '*' );
$options{'from'} = 0         if( !defined($options{'from'})|| $options{'from'} eq '*'  );
$options{'to'}   = 30000000  if( !defined($options{'to'})  || $options{'to'} eq '*' );
$options{'from'} =~ s/-//g;
$options{'to'}   =~ s/-//g;
if( !defined($options{'ws'}) || $options{'ws'} eq '*' )
{
	$options{'ws'} = '.*';
}
else
{
	$options{'ws'} = `host $options{'ws'} | gawk '{ print \$4 }'`;
	chomp $options{'ws'};
}
if( defined $options{'o'} )
{
    open STDOUT,">".$options{'o'};
    open STDERR,">".$options{'o'}.".err";
}

print "filter: $options{'uid'} $options{'url'} $options{'from'} $options{'to'} $options{'ws'} $options{'IP'}\n";
system("cat /var/log/squid/access.log | bzip2 -z  > /var/log/squid/access.log-30000000.bz2");
foreach my $f (sort(glob "/var/log/squid/access.log-*bz2") )
{
	$f =~ /access.log-(.*).bz2/;
	next if( $options{'from'} > $1 );
	next if( $over && $options{'to'} < $1 );
	$over = 1 if( $options{'to'} < $1 );
	system("cp $f /tmp/acces.bz2; bzip2 -d /tmp/acces.bz2;");
	open(IN,"/tmp/acces");
	while(<IN>)
	{
		my @line = split /\s+/, $_;
		my @T    =localtime($line[0]);
		my $date = sprintf("%4d%02d%02d", $T[5]+1900,$T[4]+1,$T[3]);
		my $time = sprintf("%02d:%02d",   $T[2],$T[1]);
		next if( $date < $options{'from'} );
		next if( $date > $options{'to'} );
		next if( $line[2] !~ /$options{'ws'}/ );
		next if( $line[6] !~ /$options{'url'}/ );
		next if( $line[7] !~ /$options{'uid'}/ );
		my $ws =  $line[2];
		if( !defined $options{'IP'} )
		{
			$ws = get_name_of_dn($oss->get_workstation($ws)); 
		}
		print "$date $time $line[7] $ws $line[6]\n";
	}
	close(IN);
	system("rm /tmp/acces");
}
$oss->destroy();
