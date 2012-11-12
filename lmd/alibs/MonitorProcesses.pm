# LMD MonitorProcesses modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package MonitorProcesses;

use strict;
use oss_base;
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
                "set"
        ];
}

sub getCapabilities
{
        return [
                 { title        => 'System Process Monitor' },
                 { type         => 'command' },
                 { allowedRole  => 'root' },
                 { allowedRole  => 'sysadmins' },
                 { category     => 'System' },
                 { order        => 80 },
                 { variable     => [  "name" => [ type => 'label']]},
                 { variable     => [  "active" => [ type => 'translatedpopup', label => 'bootstatus', style => 'width:150px;' ]]},
                 { variable     => [  "status" => [ type => 'translatedpopup', label => 'status', style => 'width:150px;' ]]},
                 { variable     => [  "set"    => [ type => 'action' ]]}
                ];
}

sub default
{
        my $this        = shift;
        my $reply       = shift;
        my @lines       = ('processes');
        my $mon_procs = $this->get_school_config('SCHOOL_MONITOR_SERVICES');
        my @procs = split ',', $mon_procs;
        my %activeProcesses = $this->getActiveProcesses();
        my $defpract = 'active';
        my $defprrun = 'started';
        my $prcolor = 'green';
        my @rcstatus = ();

        foreach my $process (@procs)
        {
            if (exists $activeProcesses{$process}) {
             $defpract = 'active';
            } else
            {
            $defpract = 'inactive';
            }

          @rcstatus = `rc$process status | grep running`;

          if (scalar(@rcstatus)>=1) {
                 $defprrun   = 'running';
                 $prcolor  = 'green';
           } else
          {
                $defprrun   = 'stopped';
		if( $defpract eq 'active' )
		{
                	$prcolor = 'red';
		}
		else
		{
			$prcolor = 'blue';
		}
          }

          my $scap = `rc$process | sed 's/|/,/g'`;
          if ($scap =~ m/({.*})/) {
            $scap = substr($1,1,-1);
            @rcstatus = split ',', $scap;
            #enhancment: what if one rcservice status does'nt return as first two params start and stop
            $rcstatus[0] = 'running';
            $rcstatus[1] = 'stopped';
            push (@rcstatus, '---DEFAULTS---',$defprrun);
            } else {
            @rcstatus =();
            push (@rcstatus, 'running','stopped','---DEFAULTS---',$defprrun);
            }
        ### removes 'status' from statuslist   
        my $k = 0;
          foreach my $i (@rcstatus) {
              if ($i eq 'status') {
                  splice (@rcstatus, $k, 1);
              }
		++$k;
          }
          push @lines, {line => [$process,
          { name  => 'name',    value =>  $process, "attributes"  => [type => "label", style => "color:".$prcolor."; width:120px;"]},
          { active=> [ 'active', 'inactive', '---DEFAULTS---',$defpract ]},
          { status => [@rcstatus] },
          { set   => main::__('service_set_status')}
          ]};
        };
        my $runlevel = `runlevel |awk '{ print \$(NF) }'`;
        return
                [
                 { notranslate_NOTICE    => main::__('services_help')." ".$runlevel},
                 { table     =>  \@lines },
                ];
}

sub getActiveProcesses
{
        my $this   = shift;
        my $reply  = shift;
        my $runlevel = `runlevel |awk '{ print \$(NF) }'`;
        my $rl = eval (2 +$runlevel) ;
        my $r  = eval $runlevel ;
        my $args = "chkconfig -l | awk '/$r/ {print "."\$"."1, \$".$rl."}' | sed 's/$r"."://'";
        my @proc_table = `$args`;
        my %processes = ();
        foreach my $pr (@proc_table) {
            my @tproc = split " ", $pr;
            if (($tproc[1]) eq "on") {
                $processes{$tproc[0]} = $tproc[1];
            }
        }
        return (%processes);
}

sub set
{
        my $this    = shift;
        my $reply   = shift;
        my $runlevel = `runlevel |awk '{ print \$(NF) }'`;
        my $service = $reply->{line};
        my $s_status  = $reply->{processes}->{$service}->{status};
        my $s_active  = $reply->{processes}->{$service}->{active};
        my %activeProcesses = $this->getActiveProcesses();
        my @rcstatus = ();
        my $st = 0;
        ### change service availability in actual runlevel if changed
        if (exists $activeProcesses{$service}) {
                if ($s_active eq 'inactive') {
                    #$service -> inactive
                    $st = system ( "chkconfig $service off");
                }
        } else {
                 if ($s_active eq 'active') {
                    #$service -> active
                    $st = system ( "chkconfig $service on ");
                }
        }
        ### stop/run/restart/reload/other... if changed
        @rcstatus = `rc$service status | grep running`;
        if (scalar(@rcstatus)>=1) {
                if ($s_status eq 'stopped') {
                    #$service -> stop
                    $st = system ( "rc".$service." stop");
                }
        }else {
                 if ($s_status eq 'running') {
                    #$service -> start
                    $st = system ( "rc".$service." start");
                }
        }
        #$service -> other status than running/stopped
        if (!(($s_status eq 'running') or ($s_status eq 'stopped'))) {
            $st = system ( "rc".$service." ".$s_status);
        }
        return  $this->default();
}


1;

