# LMD ProxyGood modul
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ProxyGood;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
my $file = "/var/lib/squidGuard/db/custom/good/domains";

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
		"Save"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Enhance the List of good Domains' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { allowedRole  => 'teachers' },
		 { allowedRole  => 'teachers,sysadmins' },
		 { category     => 'Proxy' },
		 { order        => 20 },
		 { variable     => [ "makeBackup", [ type => "boolean", label=>"Make Backup" ] ] },
		 { variable     => [ "text",   [ type => "text"  , label=>"Content" ] ] }
	];
}

sub default
{
	my $this   = shift;
	#TODO check session
	my $text;
	if ( -e $file )
	{
		$text = `cat $file`;
		chomp $text;
	}
	return [
		{ makeBackup => 1 },
		{ text       => $text },
		{ action     => "Save" }
	];
}

sub Save
{
	my $this   = shift;
	#TODO check session
	my $reply  = shift  || return undef;
	my $date   = `/usr/share/oss/tools/oss_date.sh`; chomp $date;

	if($reply->{warning}){
                my $domains = join "\n",@{$reply->{warning}};
		my $goods   = join "\n",@{$reply->{goodlist}};
		return [
			{ NOTICE => 'Incorrect domain definition in the list. Example of good domain definitions:<br>extis.de<br>download.suse.com'},
	                { text       => $domains },
			{ name       => 'goods' , value => $goods , attributes => [ type => 'hidden' ] },
	                { action     => "Save" }
	        ];
	}else{
		if( ! defined $reply->{text} )
		{
			return undef;
		}
		my $text   = $reply->{text};
		if( defined $reply->{goods} )
                {
                        $text  .= "\n".$reply->{goods};
                }
		if( defined $reply->{makeBackup} )
		{
	            system( "cp $file $file-$date");
		}

		my @content = split /\n/, $text;
		my ($good_list, $bad_list) = check_domain_name_for_proxy(\@content);

		if( scalar(@$bad_list) ){
			$reply->{warning}  = $bad_list;
                        $reply->{goodlist} = $good_list;
	                $this->Save($reply);
	        }else{
			$text = '';
			foreach my $domain(@$good_list){
				$text .= $domain."\n";
			}
			open(FILE,">$file");
			print FILE $text;
			close(FILE);
		        if( ! $this->{PROXYSERVER_LOCAL} )
		        {
		                system("scp $file proxy:$file");
		        }
		        $this->execute("/usr/sbin/squidGuard -c /etc/squid/squidguard.conf -C custom/good/domains");
			$this->execute("/usr/sbin/rcsquid reload");
			return [
				{ makeBackup => 1 },
				{ text       => $text },
				{ action     => "Save" }
			];
		}
	}
}

sub execute
{
        my $this        = shift;
        my $command     = shift;
        my $ret         = '';
        if( $this->{PROXYSERVER_LOCAL} ) {
                $ret=`$command`;
        }
        else {
                $ret=`ssh proxy '$command'`;
        }
        return $ret;
}

1;
