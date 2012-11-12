# LMD ProxyBad modul
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package squidGuard;

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;
use vars qw(@ISA);
@ISA = qw(oss_base);

my $conffile = '/etc/squid/squidguard.conf';
my $bin      = '/usr/sbin/squidGuard';


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
                "apply"
        ];

}

sub getCapabilities
{
        return [
                 { title        => 'Configure Basic Proxy Prevention' },
                 { type         => 'command' },
                 { allowedRole  => 'root' },
                 { allowedRole  => 'sysadmins' },
                 { allowedRole  => 'teachers,sysadmins' },
                 { category     => 'Proxy' },
                 { order        => 10 },
                 { variable     => [ 'makeBackup', [ type => 'boolean', label=>'Make Backup' ] ] },
                 { variable     => [ 'name',       [ type => 'label'] ]},
                 { variable     => [ 'description',[ type => 'label'] ] },
		 { variable	=> [ 'students',       [ type => 'translatedpopup' ]]},
		 { variable	=> [ 'sysadmins',      [ type => 'translatedpopup' ]]},
		 { variable	=> [ 'teachers',       [ type => 'translatedpopup' ]]},
		 { variable	=> [ 'administration', [ type => 'translatedpopup' ]]},
		 { variable	=> [ 'default',        [ type => 'translatedpopup' ]]},
        ];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my @lines = ('acls');
	my $config = parse_config();
	my $acls   = find_section($config,{ sectype => 'acl' });
	my @head   = ( 'name' );
	my %color  = ( ALLOWED => 'background-color:#00FF00',  DENIED => 'background-color:#FF0033' );
	my $allacl = {};
	my @primaries = ();
	foreach my $p (@{$this->get_school_groups('primary')})
	{
		my $cn = lc(get_name_of_dn($p));
		next if ( $cn eq 'templates' );
		my $desc = $this->get_attribute($p,'description');
		push @primaries, $cn;
		push @head, $desc ? $desc : $cn ;
	}
	push @head, 'default';
	push @lines, { head => \@head };
	push @primaries, 'default';
	foreach my $acl (@{$acls->{members}})
	{
		foreach my $p ( @{$acl->{pass}} )
		{
			if( $p eq 'all' )
			{
				$allacl->{$acl->{source}}->{all} = 'ALLOWED';
			}
			elsif( $p eq 'none' )
			{
				$allacl->{$acl->{source}}->{all} = 'DENIED';
			}
			else
			{
				$allacl->{$acl->{source}}->{$p} = ( $p =~ s/^!// ? 'DENIED' : 'ALLOWED' );
			}
		}
	}
	foreach my $acl (get_lists())
	{
		chomp $acl;
		my @line = ($acl, { name =>'name' ,value=> main::__($acl), attributes => [ type=>'label', help    => "$acl-DESC"]} );
		foreach my $p ( @primaries )
		{
			my $value;
			if( defined $allacl->{$p} )
			{
				$value = ( defined $allacl->{$p}->{$acl} )     ? $allacl->{$p}->{$acl}     : $allacl->{$p}->{all};
			}
			else
			{ # New primary group
				$value = ( defined $allacl->{default}->{$acl} )? $allacl->{default}->{$acl}: $allacl->{default}->{all};
			}
			push @line, { name=>$p, value=> [[ 'ALLOWED','ALLOWED'],['DENIED','DENIED'],'---DEFAULTS---',$value],      
					attributes=>[ type=>'translatedpopup', style=>$color{$value}, onChange=>'setColor(this)']},
		}
		push @lines , { line => \@line };
	}
	return[  
		 { notranslate_javaScript => 'function setColor(elem) {
   if (elem.value == "DENIED") {
       elem.style.backgroundColor = "#FF0033";
   } else {
      elem.style.backgroundColor = "#00FF00";
   }
 }'}, 
		 { table => \@lines },
		 { action => 'cancel'},
		 { action => 'apply'} ];
}


sub apply
{
	my $this  = shift;
	my $reply = shift;
	my %acls  = ();
	my $srcWritten = 0;
	my $aclWritten = 0;
	my @primaries = ();
	foreach my $p (@{$this->get_school_groups('primary')})
	{
		next if ( lc(get_name_of_dn($p) eq 'templates' ));
		push @primaries, lc(get_name_of_dn($p));
	}
	push @primaries, 'default';
	foreach my $acl (get_lists())
	{
		chomp $acl;
		if( $acl eq 'all' )
		{
			foreach my $p ( @primaries )
			{
				push @{$acls{$p}}, ($reply->{acls}->{$acl}->{$p} eq 'ALLOWED' ) ? 'all' : 'none';
			}
		}
		else
		{
			foreach my $p ( @primaries )
			{
				push @{$acls{$p}}, ($reply->{acls}->{$acl}->{$p} eq 'ALLOWED' ) ? $acl : "!$acl";
			}
		}
	}	
	my $config = parse_config();
	# Now we save the squidquard config file
 	open SG, ">$conffile";
	foreach my $sec ( @$config )
	{
		if( $sec->{sectype} eq 'logdir' )
		{
			print SG 'logdir '.$sec->{logdir}."\n";
		}
		elsif( $sec->{sectype} eq 'dbhome' )
		{
			print SG 'dbhome '.$sec->{dbhome}."\n";
		}
		elsif( $sec->{sectype} eq 'source' )
		{
			next if $srcWritten;
			foreach my $p ( @primaries )
			{
				next if $p eq 'default';
				print SG "src $p {\n";
				if( $p eq 'sysadmins' )
				{
					print SG "execuserlist    ldapsearch -x '(&(role=*$p)(objectclass=schoolAccount))' uid | grep uid: | sed 's/uid: //'\n"
				}
				else
				{
					print SG "execuserlist    ldapsearch -x '(&(role=$p)(objectclass=schoolAccount))' uid | grep uid: | sed 's/uid: //'\n"
				}
				print SG "}\n\n";
			}
			$srcWritten = 1;
		}
		elsif( $sec->{sectype} eq 'dest' )
		{
			print SG 'dest '.$sec->{secname}." {\n";
			print SG "\tdomainlist ".$sec->{domainlist}."\n" if ( defined $sec->{domainlist} );
			print SG "\turllist    ".$sec->{urllist}."\n"    if ( defined $sec->{urllist} );
			print SG "\tlog        ".$sec->{'log'}."\n"      if ( defined $sec->{'log'} );
			print SG "}\n\n";
		}
		elsif( $sec->{sectype} eq 'acl' )
		{
			next if $aclWritten;
			print SG "acl {\n";
			foreach my $p ( @primaries )
			{
				print SG "\t$p {\n";
				print SG "\t\tpass ".join(" ",@{$acls{$p}})."\n";
				print SG "\t\tredirect ".'302:http://admin/cgi-bin/oss-stop.cgi/?clientaddr=%a&clientname=%n&clientident=%i&srcclass='.$p.'&targetclass=%t&url=%u'."\n";
				print SG "\t}\n";
			}
			print SG "}\n\n";
			$aclWritten = 1;
		}	
	}
	close SG;
	if( ! $this->{PROXYSERVER_LOCAL} )
	{
		system("scp $conffile proxy:$conffile");
	}
	$this->execute("chown -R squid /var/log/squidGuard/");
	$this->execute("/etc/init.d/squid reload > /dev/null & 2>1 ");
	return {
		TYPE => 'NOTICE',
		MESSAGE => 'Squid will be restarted. That can take 1-2 minutes.'
	};
}

sub get_lists
{
	open(IN,"/usr/share/lmd/alibs/squidGuard/blacklists");
	my @BL = <IN>;
	close(IN);
	@BL = main::sort_by_lang(\@BL);
	open(IN,"/usr/share/lmd/alibs/squidGuard/whitelists");
	my @WL = <IN>;
	close(IN);
	@WL = main::sort_by_lang(\@WL);
	my @LISTS = ('good','bad','in-addr');
        push @LISTS, @WL,@BL,'all';
	return @LISTS;
}
############## Helper funktions from webmin #########
#    SquidGuard Configuration Webmin Module Library
#    Copyright (C) 2001 by Tim Niemueller <tim@niemueller.de>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    Created  : 26.03.2001
#    Modified by Peter Varkoly : 21.05.2009

my $_DEBUG=0;

sub parse_config {

  # Do NOT use read_file_lines here, otherwise a
  # flush_file_lines in save_*.cgi would have
  # Very Bad Side-Effects (TM)

  open(CONF, $conffile);
    my @c=<CONF>;
  close(CONF);
  my @config=();
  my $counter = 0;

  for (my $i=0; $i < @c; $i++) {
    $c[$i] = unify($c[$i]);

    next if (!$c[$i] || ($c[$i] =~ /^#/));
    print "$i: $c[$i]<BR>\n" if $_DEBUG;

    if ($c[$i] =~ /^dbhome\s+(\S+)/) {

      ###### DB Home

      my %section;
	 $section{'counter'}=$counter++;
         $section{'sectype'}='dbhome';
         $section{'dbhome'}=$1;
         $section{'line'}=$i;

      print "<B>dbhome token found (i: $i, dbhome: $section{'dbhome'})</B><BR>\n" if $_DEBUG;

      push(@config, \%section);

    } elsif ($c[$i] =~ /^logdir\s+(\S+)/) {

      ###### Log Dir

      my %section;
	 $section{'counter'}=$counter++;
         $section{'sectype'}='logdir';
         $section{'logdir'}=$1;
         $section{'line'}=$i;

      print "<B>logdir token found (i: $i, logdir: $section{'logdir'})</B><BR>\n" if $_DEBUG;

      push(@config, \%section);

    } elsif ($c[$i] =~ /^time\s+([-_.a-zA-Z0-9]+)\s+\{\s*$/) {

      ###### Timespace

      my %section;
	 $section{'counter'}=$counter++;
         $section{'sectype'}='time';
         $section{'secname'}=$1;
         $section{'line'}=$i;

      my @members=();
      $c[$i] = unify($c[++$i]);
      while(($i < scalar(@c)) && ($c[$i] !~ /^\s*\}/)) {
        $c[$i] = unify($c[$i]);
        if ( ($c[$i] =~ /^weekly\s(.*)\s(\d\d:\d\d\s?-\s?\d\d:\d\d)/) ||
             ($c[$i] =~ /^weekly\s(.*)/) ) {
          print "<B>weekly token found</B><BR>\n" if $_DEBUG;
          my %st;
             $st{'stype'} = 'weekly';
             $st{'time'} = $2;
             $st{'line'} = $i;
             $st{'rawdays'} = $1;

          $st{'time'} =~ s/\s//g;
          my ($from, $to) = split(/-/, $st{'time'}, 2);
          ($st{'shour'}, $st{'smin'}) = split(/:/, $from);
          ($st{'ehour'}, $st{'emin'}) = split(/:/, $to);

          my @r=split(/\s?/, $st{'rawdays'});
          my $d='';
          foreach my $s (@r) {
            print "S: $s<BR>\n" if $_DEBUG;
            if ($s eq '*') {
              $d='*';        # 128
              last;
            } elsif ($s =~ /m(ondays?)?/) {
              $d.='m';       # ++
            } elsif ($s =~ /t(uesdays?)?/) {
              $d.='t';       ## +=2;
            } elsif ($s =~ /w(ednesdays?)?/) {
              $d.='w';       ## +=4;
            } elsif ($s =~ /t?h(ursdays?)?/) {
              $d.='h';       ## +=8;
            } elsif ($s =~ /f(ridays?)?/) {
              $d.='f';       ## +=16;
            } elsif ($s =~ /s?a(turdays?)?/) {
              $d.='a';       ## +=32;
            } elsif ($s =~ /s(undays?)?/) {
              $d.='s';       ## +=64;
            }
          }
          $st{'days'}=$d;
          push(@members, \%st);
        } elsif ( ($c[$i] =~ /^date\s+(\d\d\d\d|\*)[.-](\d\d|\*)[.-](\d\d|\*)\s*(\d\d:\d\d\s?-\s?\d\d:\d\d)/) ) {
          #        ($c[$i] =~ /^date\s (\d\d|\*)[.-](\d\d|\*)[.-](\d\d|\*)/) ) {
          # 
          print "<B>date token found - 1</B><BR>\n" if $_DEBUG;
          my %st;
          $st{'stype'}='date';
          $st{'line'} = $i;
          $st{'syear'}=$1;
          $st{'syear'}+=2000 if (length($st{'syear'}==2));
          $st{'smonth'}=$2;
          $st{'sday'}=$3;
          $st{'time'}=$4;

          $st{'time'} =~ s/\s//g;
          my ($from, $to) = split(/-/, $st{'time'}, 2);
          ($st{'shour'}, $st{'smin'}) = split(/:/, $from);
          ($st{'ehour'}, $st{'emin'}) = split(/:/, $to);

          push(@members, \%st);

       } elsif (($c[$i] =~ /^date\s+(\d\d\d\d|\*)[.-](\d\d|\*)[.-](\d\d|\*)-(\d\d\d\d|\*)[.-](\d\d|\*)[.-](\d\d|\*)\s*(\d\d:\d\d\s?-\s?\d\d:\d\d)/) ||
                ($c[$i] =~ /^date\s+(\d\d\d\d|\*)[.-](\d\d|\*)[.-](\d\d|\*)-(\d\d\d\d|\*)[.-](\d\d|\*)[.-](\d\d|\*)/) ) {
          print "<B>date range token found (l: $i, i: ", scalar(@members), ")</B><BR>\n" if $_DEBUG;
          my %st;
          $st{'stype'}='date_range';
          $st{'line'} = $i;
          $st{'syear'}=$1;
          $st{'smonth'}=$2;
          $st{'sday'}=$3;
          $st{'eyear'}=$4;
          $st{'emonth'}=$5;
          $st{'eday'}=$6;
          $st{'time'}=$7;

          $st{'time'} =~ s/\s//g;
          my ($from, $to) = split(/-/, $st{'time'}, 2);
          ($st{'shour'}, $st{'smin'}) = split(/:/, $from);
          ($st{'ehour'}, $st{'emin'}) = split(/:/, $to);

          push(@members, \%st);

        }
        $i++;
      } # End of while

      # All empty lines after the section
      # are counted to the section
      while (($i+1 < scalar(@c)) && (unify($c[$i+1]) eq "")) {
        $i++;
        $c[$i] = unify($c[$i]);
      }
      $section{'end_line'} = $i;

      $section{'members'}=\@members;
      push(@config, \%section);
    } elsif ($c[$i] =~ /^(src|source)\s+([-_.a-zA-Z0-9]+)\s+((within|outside)\s+([-_.a-zA-Z0-9]+)\s+)?\{\s*$/) {

      ###### Source Group

      print "<B>source token found ($i)</B><BR>\n" if $_DEBUG;
      my %section;
	 $section{'counter'}=$counter++;
         $section{'sectype'}='source';
         $section{'secname'}=$2;
         $section{'line'}=$i;
         $section{'tstype'} = $4;
         $section{'timespace'} = $5;
      my @members=();

      $c[$i] = unify($c[++$i]);
      while(($i < scalar(@c)) && ($c[$i] !~ /^\s*\}/)) {
        $c[$i] = unify($c[$i]);

        if ($c[$i] =~ /^ip\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
          my %st;
             $st{'stype'}='subnet_long';
             $st{'line'}=$i;
             $st{'ip'}=$1;
             $st{'mask'}=$2;
          push(@members, \%st);
        } elsif ($c[$i] =~ /^ip\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})-(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
          my %st;
             $st{'stype'}='iprange';
             $st{'line'}=$i;
             $st{'ip'}=$1;
             $st{'end'}=$2;
          push(@members, \%st);
        } elsif ($c[$i] =~ /^ip\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d\d?)/) {
          my %st;
             $st{'stype'}='subnet';
             $st{'line'}=$i;
             $st{'ip'}=$1;
             $st{'prefix'}=$2;
          push(@members, \%st);
        } elsif ($c[$i] =~ /^ip\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) {
          my %st;
             $st{'stype'}='ip';
             $st{'line'}=$i;
             $st{'ip'}=$1;
          push(@members, \%st);


        } elsif ($c[$i] =~ /^domain\s+(\S+)/) {
          my %st;
             $st{'stype'}='domain';
             $st{'line'}=$i;
             $st{'domain'}=$1;
          push(@members, \%st);

        } elsif ($c[$i] =~ /^user\s+(\S+)/) {
          my %st;
             $st{'stype'}='user';
             $st{'line'}=$i;
             $st{'user'}=$1;
          push(@members, \%st);
        } elsif ($c[$i] =~ /^userlist\s+(\S+)/) {
          my %st;
             $st{'stype'}='userlist';
             $st{'line'}=$i;
             $st{'userlist'}=$1;
             $st{'userlist'} =~ /\/?([^\/]+)$/;
             $st{'name'}=$1;
          push(@members, \%st);
        } elsif ($c[$i] =~ /^execuserlist\s+(.*)/) {
          my %st;
             $st{'stype'}='execuserlist';
             $st{'line'}=$i;
             $st{'execuserlist'}=$1;
          push(@members, \%st);
        }

        $i++;
      }

      # All empty lines after the section
      # are counted to the section
      while (($i+1 < scalar(@c)) && (unify($c[$i+1]) eq "")) {
        $i++;
        $c[$i] = unify($c[$i]);
      }
      $section{'end_line'} = $i;

      $section{'members'}=\@members;
      push(@config, \%section);
    } elsif ($c[$i] =~ /^(dest|destination)\s+([-_.a-zA-Z0-9]+)(\s+(within|outside)\s+([-_.a-zA-Z0-9]+))?\s+\{\s*$/) {

      ###### destination group

      print "<B>destination token found ($i)</B><BR>\n" if $_DEBUG;
      my %section;
	 $section{'counter'}=$counter++;
         $section{'sectype'}='dest';
         $section{'secname'}=$2;
         $section{'line'}=$i;
         $section{'tstype'}=$4;
         $section{'timespace'}=$5;

      $c[$i] = unify($c[++$i]);
      while(($i < scalar(@c)) && ($c[$i] !~ /^\s*\}/)) {
        $c[$i] = unify($c[$i]);

        if ($c[$i] =~ /^domainlist\s+(\S+)/) {
          $section{'domainlist'}=$1;
          $section{'domainlist_line'} = $i;
        } elsif ($c[$i] =~ /^urllist\s+(\S+)/) {
          $section{'urllist'}=$1;
          $section{'urllist_line'} = $i;
        } elsif ($c[$i] =~ /^expressionlist\s+(\S+)/) {
          $section{'exprlist'}=$1;
          $section{'exprlist_line'} = $i;
        } elsif ($c[$i] =~ /^log\s+(\S+)/) {
          $section{'log'}=$1;
          $section{'log_line'} = $i;
        }
        $i++;
      }

      # All empty lines after the section
      # are counted to the section
      while (($i+1 < scalar(@c)) && (unify($c[$i+1]) eq "")) {
        $i++;
        $c[$i] = unify($c[$i]);
      }
      $section{'end_line'} = $i;

      push(@config, \%section);


    } elsif ($c[$i] =~ /^(rew|rewrite)\s+([-_.a-zA-Z0-9]+)\s+((within|outside)\s+([-_.a-zA-Z0-9]+)\s+)?\{\s*$/) {

      ###### Rewrite group

      print "<B>rewrite token found ($i)</B><BR>\n" if $_DEBUG;
      my %section;
	 $section{'counter'}=$counter++;
         $section{'sectype'}='rewrite';
         $section{'secname'}=$2;
         $section{'line'}=$i;
         $section{'tstype'} = $4;
         $section{'timespace'} = $5;

      my @members=();
      $c[$i] = unify($c[++$i]);
      while(($i < scalar(@c)) && ($c[$i] !~ /^\s*\}/)) {
        $c[$i] = unify($c[$i]);

        if ($c[$i] =~ /^s\@(\S+)\@(\S+)\@(i?)(r?)(R?)/) {
          my %st=();
             $st{'stype'}='rew';
             $st{'line'}=$i;
             $st{'from'}=$1;
             $st{'to'}=$2;
             $st{'flag_i'} = $3 ? 1 : 0;
             $st{'flag_r'} = $4 ? 1 : 0;
             $st{'flag_R'} = $5 ? 1 : 0;
          push(@members, \%st);  
        }

        $i++;
      }
      $section{'members'}=\@members;

      # All empty lines after the section
      # are counted to the section
      while (($i+1 < scalar(@c)) && (unify($c[$i+1]) eq "")) {
        $i++;
        $c[$i] = unify($c[$i]);
      }
      $section{'end_line'} = $i;


      push(@config, \%section);


    } elsif ($c[$i] =~ /^acl\s+\{\s*$/) {

      ###### ACL

      print "<B>acl token found ($i)</B><BR>\n" if $_DEBUG;
      my %section;
	 $section{'counter'}=$counter++;
         $section{'sectype'}='acl';
         $section{'secname'}=$2;
         $section{'line'}=$i;

      my @members=();
      $c[$i] = unify($c[++$i]);
      while(($i < scalar(@c)) && ($c[$i] !~ /^\s*\}/)) {
        if ($c[$i] =~ /\s*([-_.a-zA-Z0-9]+)\s+((within|outside)\s+([-_.a-zA-Z0-9]+)\s+)?\{/ ) {
            my %st;
               $st{'stype'} = 'acl_item';
               $st{'line'} = $i;
               $st{'source'} = $1;
               $st{'tstype'} = $3 ? $3 : 'none';
               $st{'timespace'} = $4;

            print "<B>acl_item found ($i)</B><BR><UL>\n",
                  "<LI>source: $st{'source'}</LI>\n",
                  "<LI>tstype: $st{'tstype'}</LI>\n",
                  "<LI>timespace: $st{'timespace'}</LI></UL>\n"
              if ($_DEBUG);

          $c[$i] = unify($c[++$i]);
          while (($i < scalar(@c)) && ($c[$i] !~ /^\s*\}/)) {
            if ($c[$i] =~ /^pass/) {
              my @pass=split(/\s+/, $c[$i]);
              shift @pass; # delete the first, it's always 'pass'...
              $st{'pass'} = \@pass;
              $st{'pass_line'} = $i;
              print "<I>Pass Statement: $c[$i]</I><BR>",
                    join('::', @pass), "-> ", scalar(@pass), "<BR>" if $_DEBUG;
            } elsif ($c[$i] =~ /^rewrite/) {
              my @rew = split(/\s+/, $c[$i]);
              shift @rew; # delete the first, it's always 'rewrite'...
              $st{'rewrite'} = \@rew;
              $st{'rewrite_line'} = $i;
              print "<I>Rewrite Statement: $c[$i]</I><BR>\n" if $_DEBUG;
            } elsif ($c[$i] =~ /^redirect\s+(.*)/) {
              my $tmp=$1;
              $tmp =~ /((301|302):)?(.*)/;
              $st{'redmode'} = $2;
              $st{'redurl'} = $3;
              $st{'redirect_line'} = $i;
              print "<I>Redirection Statement: $c[$i]</I><BR>\n" if $_DEBUG;
            } else {
              print "<I>Unknown Statement: $c[$i]</I><BR>\n" if $_DEBUG;
            }

            $c[$i] = unify($c[++$i]);
          } # end inner while

          # All empty lines after the section
          # are counted to the section
          while (($i+1 < scalar(@c)) && (unify($c[$i+1]) eq "")) {
            $i++;
            $c[$i] = unify($c[$i]);
          }
          $st{'end_line'} = $i;

          push(@members, \%st);
        } # end if start of acl_item
        $i++;
        $c[$i] = unify($c[$i]);
      } # end outer while
      $section{'members'} = \@members;

      # All empty lines after the section
      # are counted to the section
      while (($i+1 < scalar(@c)) && (unify($c[$i+1]) eq "")) {
        $i++;
        $c[$i] = unify($c[$i]);
      }
      $section{'end_line'} = $i;

      push(@config, \%section);
    }

  } # End main FOR loop

return wantarray ? @config : \@config;
}



sub find_section {
  my $config = shift;
  my $args   = shift;

  foreach my $c (@{$config}) {
    my $ok=1;
    for (keys %$args) {
      next if ($_ eq 'config');
      if ($c->{$_} !~ /^$args->{$_}$/) {
        $ok=0;
        last;
      }
    }

    return $c if ($ok);
  }

return undef;
}


# sgchown($file)
# Change user/group of file to squid
sub sgchown {
  if (-e $_[0]) {
    system("chown squid:nobody $_[0]");
  }
}
  


# rebuild_db($file)
# Rebuild the dbfile $file with squidguard -C
sub rebuild_db {
  system("$bin -C '$_[0]' -c '$conffile");
  reload_squid();
}

# reload_squid
# Send Squid the HUP signal when db is rebuild
sub reload_squid {
    system("/etc/init.d/squid reload");
}

sub unify {
  my $string=$_[0];
  chomp $string;
  $string =~ s/\t+/ /g;
  $string =~ s/\s+/ /g;
  $string =~ s/^\s+//;

return $string;
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

