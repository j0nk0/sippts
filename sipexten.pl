#!/usr/bin/perl
# -=-=-=-=-=-=-=-
# SipExten v1.2.2
# -=-=-=-=-=-=-=-
#
# Pepelux <pepeluxx@gmail.com>
 
use warnings;
use strict;
use IO::Socket;
use IO::Socket::Timeout;
use NetAddr::IP;
use threads;
use threads::shared;
use Getopt::Long;
use Digest::MD5;
use DBI;

my $useragent = 'pplsip';
my $version = '1.2.2';

my $maxthreads = 300;
 
my $threads : shared = 0;
my $found : shared = 0;
my $count : shared = 0;
my @range;
my @results;
 
my $host = '';		# host
my $lport = '';		# local port
my $dport = '';		# destination port
my $from = '';		# source number
my $to = '';		# destination number
my $v = 0;		# verbose mode
my $vv = 0;		# more verbose
my $nolog = 0;
my $exten = '';		# extension
my $prefix = '';	# prefix
my $proto = '';		# protocol
my $withdb = 0;

my $to_ip = '';
my $from_ip = '';

my $database = "sippts.db";
my $database_empty = "sippts_empty.db";

mkdir ("tmp") if (! -d "tmp");
my $tmpfile = "tmp/sipexten".time().".txt";
 
unless (-e $database || -e $database_empty) {
	die("Database $database not found\n\n");
}

system("cp $database_empty $database") if (! -e $database);
	
my $db = DBI->connect("dbi:SQLite:dbname=$database","","") or die $DBI::errstr;
my $extensid = last_id("extens");
my $hostsid = last_id("hosts");

open(OUTPUT,">$tmpfile");
 
OUTPUT->autoflush(1);
STDOUT->autoflush(1);
 
$SIG{INT} = \&interrupt;

sub init() {
    my $pini;
    my $pfin;
    my $eini;
    my $efin;
 
    # check params
    my $result = GetOptions ("h=s" => \$host,
				"d=s" => \$to,
				"s=s" => \$from,
				"ip=s" => \$from_ip,
				"e=s" => \$exten,
				"l=s" => \$lport,
				"r=s" => \$dport,
				"proto=s" => \$proto,
				"p=s" => \$prefix,
				"db+" => \$withdb,
				"nolog+" => \$nolog,
				"ua=s" => \$useragent,
				"v+" => \$v,
				"vv+" => \$vv);
 
	help() if ($host eq "");
	check_version();

	$lport = "5070" if ($lport eq "");
	$dport = "5060" if ($dport eq "");
	$exten = "100-300" if ($exten eq "");
	$proto = lc($proto);
	$proto = "all" if ($proto ne "tcp" && $proto ne "udp");

	my @hostlist;

	if ($host =~ /\,/) {
		@hostlist = split(/\,/, $host);

		foreach(@hostlist) {
			my $line = $_;

			if ($line =~ /\-/) {
				my $ip = $line;

				$ip =~ /([0-9|\.]*)-([0-9|\.]*)/;
				my $ipini = $1;
				my $ipfin = $2;

				my $ip2 = $ipini;
				$ip2 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
				my $ip2_1 = int($1);
				my $ip2_2 = int($2);
				my $ip2_3 = int($3);
				my $ip2_4 = int($4);

				my $ip3 = $ipfin;
				$ip3 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
				my $ip3_1 = int($1);
				my $ip3_2 = int($2);
				my $ip3_3 = int($3);
				my $ip3_4 = int($4);

				for (my $i1 = $ip2_1; $i1 <= $ip3_1; $i1++) {
					for (my $i2 = $ip2_2; $i2 <= $ip3_2; $i2++) {
						for (my $i3 = $ip2_3; $i3 <= $ip3_3; $i3++) {
							for (my $i4 = $ip2_4; $i4 <= $ip3_4; $i4++) {
								$ip = "$i1.$i2.$i3.$i4";
								push @range, $ip;
							}
				
							$ip2_4 = 1;
						}
				
						$ip2_3 = 1;
					}
				
					$ip2_2 = 1;
				}
			}
			else {
				my $ip = new NetAddr::IP($line);

				if ($ip < $ip->broadcast) {
					$ip++;

					while ($ip < $ip->broadcast) {
						my $ip2 = $ip;
						$ip2 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
						$ip2 = "$1.$2.$3.$4";
						push @range, $ip2;
						$ip++;
					}
				}
				else {
					push @range, $line;
				}
			}
		}
	}
	else {
		if ($host =~ /\-/) {
			my $ip = $host;

			$ip =~ /([0-9|\.]*)-([0-9|\.]*)/;
			my $ipini = $1;
			my $ipfin = $2;

			my $ip2 = $ipini;
			$ip2 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
			my $ip2_1 = int($1);
			my $ip2_2 = int($2);
			my $ip2_3 = int($3);
			my $ip2_4 = int($4);

			my $ip3 = $ipfin;
			$ip3 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
			my $ip3_1 = int($1);
			my $ip3_2 = int($2);
			my $ip3_3 = int($3);
			my $ip3_4 = int($4);

			for (my $i1 = $ip2_1; $i1 <= $ip3_1; $i1++) {
				for (my $i2 = $ip2_2; $i2 <= $ip3_2; $i2++) {
					for (my $i3 = $ip2_3; $i3 <= $ip3_3; $i3++) {
						for (my $i4 = $ip2_4; $i4 <= $ip3_4; $i4++) {
							$ip = "$i1.$i2.$i3.$i4";
							push @range, $ip;
						}
					}
				}
			}
		}
		else {
			my $ip = new NetAddr::IP($host);

			if ($ip < $ip->broadcast) {
				$ip++;

				while ($ip < $ip->broadcast) {
					my $ip2 = $ip;
					$ip2 =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/;
					$ip2 = "$1.$2.$3.$4";
					push @range, $ip2;
					$ip++;
				}
			}
			else {
				push @range, $host;
			}
		}
	}

	if ($dport =~ /\-/) {
		$dport =~ /([0-9]*)-([0-9]*)/;
		$pini = $1;
		$pfin = $2;
	}
	else {
		$pini = $dport;
		$pfin = $dport;
	}

	if ($exten =~ /\-/) {
		$exten =~ /([0-9]*)-([0-9]*)/;
		$eini = $1;
		$efin = $2;
	}
	else {
		$eini = $exten;
		$efin = $exten;
	}

	my $nhost = @range;
 
	for (my $i = 0; $i <= $nhost; $i++) {
		for (my $j = $pini; $j <= $pfin; $j++) {
			for (my $k = $eini; $k <= $efin; $k++) {
				while (1) {
					if ($threads < $maxthreads) {
						$from = $prefix.$k if ($from eq "" || $eini ne $efin);
						$to = $prefix.$k if ($to eq "" || $eini ne $efin);
						last unless defined($range[$i]);
						my $csec = 1;
						$from_ip = $range[$i] if ($from_ip eq "");
						my $thr = threads->new(\&scan, $range[$i], $from_ip, $lport, $j, $from, $to, $csec, $prefix.$k, $proto);
						$thr->detach();

						last;
					}
					else {
						sleep(1);
					}
				}
			}
		}
	}

	sleep(1);

	close(OUTPUT);

	showres();
	unlink($tmpfile);

	exit;
}

sub showres {
	open(OUTPUT, $tmpfile);
 
 	if ($nolog eq 0) {
		print "\nIP address\tPort\tProto\tExtension\tAuthentication\t\tUser-Agent\n";
		print "==========\t====\t=====\t=========\t==============\t\t==========\n";
	}

	my @results = <OUTPUT>;
	close (OUTPUT);

	@results = sort(@results);

	foreach(@results) {
		my $line = $_;
		print $line if ($nolog eq 0);
		save($line) if ($withdb eq 1);
	}

	print "\n";
}

sub last_id {
	my $cdb = shift;

	my $sth = $db->prepare("SELECT id FROM $cdb ORDER BY id DESC LIMIT 1") or die "Couldn't prepare statement: " . $db->errstr;
	$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
	my @data = $sth->fetchrow_array();
	$sth->finish;
	if ($#data > -1) { return $data[0] + 1; }
	else { return 1; }
}

sub interrupt {
	close(OUTPUT);

	showres();
	unlink($tmpfile);

	exit;
}

sub save {
	my $line = shift;

		my @lines = split (/\t/, $line);
		my $sth = $db->prepare("SELECT id FROM hosts WHERE host='".$lines[0]."'") or die "Couldn't prepare statement: " . $db->errstr;
		$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
		my @data = $sth->fetchrow_array();
		my $sql;
		$sth->finish;
		if ($#data < 0) {
			$sql = "INSERT INTO hosts (id, host, port, proto, useragent) VALUES ($hostsid, '".$lines[0]."', ".$lines[1].", '".$lines[2]."', '".$lines[6]."')";
			$db->do($sql);
			$hostsid = $db->func('last_insert_rowid') + 1;
		}

		$sth = $db->prepare("SELECT id FROM extens WHERE host='".$lines[0]."' AND exten='".$lines[3]."'") or die "Couldn't prepare statement: " . $db->errstr;
		$sth->execute() or die "Couldn't execute statement: " . $sth->errstr;
		@data = $sth->fetchrow_array();
		$sth->finish;
		if ($#data < 0) {
			$sql = "INSERT INTO extens (id, host, port, proto, exten, auth) VALUES ($extensid, '".$lines[0]."', ".$lines[1].", '".$lines[2]."', '".$lines[3]."', '".$lines[5]."')";
			$db->do($sql);
			$extensid = $db->func('last_insert_rowid') + 1;
		}
		else {
			$sql = "UPDATE extens SET port=".$lines[1].", proto='".$lines[2]."', auth='".$lines[5]."' WHERE host='".$lines[0]."' AND exten='".$lines[3]."'";
			$db->do($sql);
		}
}

sub scan {
	my $to_ip = shift;
	my $from_ip = shift;
	my $lport = shift;
	my $dport = shift;
	my $from = shift;
	my $to = shift;
	my $csec = shift;
	my $user = shift;
	my $proto = shift;

	my $p = $proto;
	
	$p = "udp" if ($proto eq "all");
	my $r = send_options($from_ip, $to_ip, $lport, $dport, $from, $to, $csec, $user, $p);
	send_options($from_ip, $to_ip, $lport, $dport, $from, $to, $csec, $user, "tcp") if ($proto eq "all" && $r eq "");
}
 
# Send INVITE message
sub send_invite {
	my $from_ip = shift;
	my $to_ip = shift;
	my $lport = shift;
	my $dport = shift;
	my $from = shift;
	my $to = shift;
	my $cseq = shift;
	my $user = shift;
	my $proto = shift;
	my $response = "";

	my $sc = new IO::Socket::INET->new(PeerPort=>$dport, Proto=>$proto, PeerAddr=>$to_ip, Timeout => 10);

	if ($sc) {
		IO::Socket::Timeout->enable_timeouts_on($sc);
		$sc->read_timeout(0.5);
		$sc->enable_timeout;
		$lport = $sc->sockport();

		my $branch = &generate_random_string(71, 0);
		my $callid = &generate_random_string(32, 1);
	
		my $msg = "INVITE sip:".$to."@".$to_ip." SIP/2.0\n";
		$msg .= "Via: SIP/2.0/".uc($proto)." $from_ip:$lport;branch=$branch\n";
		$msg .= "From: \"$from\" <sip:".$user."@".$to_ip.">;tag=0c26cd11\n";
		$msg .= "To: <sip:".$to."@".$to_ip.">\n";
		$msg .= "Contact: <sip:".$from."@".$from_ip.":$lport;transport=$proto>\n";
		$msg .= "Supported: replaces, timer, path\n";
		$msg .= "P-Early-Media: Supported\n";
		$msg .= "Call-ID: ".$callid."\n";
		$msg .= "CSeq: $cseq INVITE\n";
		$msg .= "User-Agent: $useragent\n";
		$msg .= "Max-Forwards: 70\n";
		$msg .= "Allow: INVITE,ACK,CANCEL,BYE,NOTIFY,REFER,OPTIONS,INFO,SUBSCRIBE,UPDATE,PRACK,MESSAGE\n";
		$msg .= "Content-Type: application/sdp\n";

		my $sdp .= "v=0\n";
		$sdp .= "o=anonymous 1312841870 1312841870 IN IP4 $from_ip\n";
		$sdp .= "s=session\n";
		$sdp .= "c=IN IP4 $from_ip\n";
		$sdp .= "t=0 0\n";
		$sdp .= "m=audio 2362 RTP/AVP 0\n";
		$sdp .= "a=rtpmap:18 G729/8000\n";
		$sdp .= "a=rtpmap:0 PCMU/8000\n";
		$sdp .= "a=rtpmap:8 PCMA/8000\n";

		$msg .= "Content-Length: ".length($sdp)."\n\n";
		$msg .= $sdp;

		my $data = "";
		my $server = "";
		my $ua = "";
		my $line = "";

		print $sc $msg;

		print "[+] $to_ip:$dport/$proto - Sending INVITE $from => $to\n" if ($v eq 1);
		print "[+] $to_ip:$dport/$proto - Sending:\n=======\n$msg" if ($vv eq 1);

		use Errno qw(ETIMEDOUT EWOULDBLOCK);
		
		LOOP: {
			while (<$sc>) {
				if ( 0+$! == ETIMEDOUT || 0+$! == EWOULDBLOCK ) {
					{lock($threads);$threads--;}
					return "";
				}

				$line = $_;
			
				if ($line =~ /^SIP\/2.0/ && $response eq "") {
					$line =~ /^SIP\/2.0\s(.+)\r\n/;
				
					if ($1) { $response = $1; }
				}

				$data .= $line;
 
				if ($line =~ /^\r\n/) {
					print "[-] $response\n" if ($v eq 1);
					print "Receiving:\n=========\n$data" if ($vv eq 1);

					last LOOP;
				}
			}
		}
    	}
	
	return $response;
}

# Send OPTIONS message
sub send_options {
	{lock($count);$count++;}
	{lock($threads);$threads++;}
 
	my $from_ip = shift;
	my $to_ip = shift;
	my $lport = shift;
	my $dport = shift;
	my $from = shift;
	my $to = shift;
	my $csec = shift;
	my $user = shift;
	my $proto = shift;
	my $response = "";

	my $sc = new IO::Socket::INET->new(PeerPort=>$dport, Proto=>$proto, PeerAddr=>$to_ip, Timeout => 10);

	if ($sc) {
		IO::Socket::Timeout->enable_timeouts_on($sc);
		$sc->read_timeout(1);
		$sc->enable_timeout;
		$lport = $sc->sockport();

		my $branch = &generate_random_string(71, 0);
		my $callid = &generate_random_string(32, 1);
	
		my $msg = "OPTIONS sip:".$to."@".$to_ip." SIP/2.0\n";
		$msg .= "Via: SIP/2.0/".uc($proto)." $from_ip:$lport;branch=$branch\n";
		$msg .= "From: <sip:".$user."@".$to_ip.">;tag=0c26cd11\n";
		$msg .= "To: <sip:".$user."@".$to_ip.">\n";
		$msg .= "Contact: <sip:".$user."@".$from_ip.":$lport;transport=$proto>\n";
		$msg .= "Call-ID: ".$callid."\n";
		$msg .= "CSeq: $csec OPTIONS\n";
		$msg .= "User-Agent: $useragent\n";
		$msg .= "Max-Forwards: 70\n";
		$msg .= "Allow: INVITE,ACK,CANCEL,BYE,NOTIFY,REFER,OPTIONS,INFO,SUBSCRIBE,UPDATE,PRACK,MESSAGE\n";
		$msg .= "Content-Length: 0\n\n";

		my $data = "";
		my $server = "";
		my $ua = "";
		my $line = "";

		print $sc $msg;

		print "[+] $to_ip:$dport/$proto - Sending OPTIONS $from => $to\n" if ($v eq 1);
		print "[+] $to_ip:$dport/$proto - Sending:\n=======\n$msg" if ($vv eq 1);

		use Errno qw(ETIMEDOUT EWOULDBLOCK);
		
		LOOP: {
			while (<$sc>) {
				if ( 0+$! == ETIMEDOUT || 0+$! == EWOULDBLOCK ) {
					{lock($threads);$threads--;}
					return "";
				}

				$line = $_;
			
				if ($line =~ /^SIP\/2.0/ && $response eq "") {
					$line =~ /^SIP\/2.0\s(.+)\r\n/;
				
					if ($1) { $response = $1; }
				}

				if ($line =~ /[Ss]erver/ && $server eq "") {
					$line =~ /[Ss]erver\:\s(.+)\r\n/;
 
					$server = $1 if ($1);
				}

				if ($line =~ /[Uu]ser\-[Aa]gent/ && $ua eq "") {
					$line =~ /[Uu]ser\-[Aa]gent\:\s(.+)\r\n/;
 
					$ua = $1 if ($1);
				}

				$data .= $line;
 
				if ($line =~ /^\r\n/) {
					print "[-] $response\n" if ($v eq 1);
					print "Receiving:\n=========\n$data" if ($vv eq 1);

					last LOOP if ($response !~ /^1/);
				}
			}
		}
   
		if ($response =~ "^200") {
			if ($server eq "") {
				$server = $ua;
			}
			else {
				if ($ua ne "") {
					$server .= " - $ua";
				}
			}

			$server = "Unknown" if ($server eq "");
			my $resinvite = send_invite($from_ip, $to_ip, $lport, $dport, $from, $to, $csec, $user, $proto);
			if ($resinvite =~ "^1") {
				print OUTPUT "$to_ip\t$dport\t$proto\t$to\t\tNo authentication required\t$server\n";
			}
			else {
				print OUTPUT "$to_ip\t$dport\t$proto\t$to\t\tRequire authentication\t$server\n";
			}
			{lock($found);$found++;}
		}
	}
	
	{lock($threads);$threads--;}
	
	return $response;
}

 
sub generate_random_string {
    my $length_of_randomstring = shift;
    my $only_hex = shift;
    my @chars;
 
    if ($only_hex == 0) {
        @chars = ('a'..'z','0'..'9');
    }
    else {
        @chars = ('a'..'f','0'..'9');
    }
    my $random_string;
    foreach (1..$length_of_randomstring) {
        $random_string.=$chars[rand @chars];
    }
    return $random_string;
}
 
sub check_version {
	my $v = `curl -s https://raw.githubusercontent.com/Pepelux/sippts/master/version`;
	$v =~ s/\n//g;

	if ($v ne $version) {	
		print "The current version ($version) is outdated. There is a new version ($v). Please update:\n";
		print "https://github.com/Pepelux/sippts\n";
	}
}

sub help {
    print qq{
SipEXTEN - by Pepelux <pepeluxx\@gmail.com>
--------

Usage: perl $0 -h <host> [options]
 
== Options ==
-e  <string>     = Extensions (default 100-300)
-s  <integer>    = Source number (CallerID) (default: 100)
-d  <integer>    = Destination number (default: 100)
-r  <integer>    = Remote port (default: 5060)
-p  <string>     = Prefix (for extensions)
-proto <string>  = Protocol (udp, tcp or all (both of them) - By default: ALL)
-ip <string>     = Source IP (by default it is the same as host)
-ua <string>     = Customize the UserAgent
-db              = Save results into database (sippts.db)
-nolog           = Don't show anything on the console
-v               = Verbose (trace information)
-vv              = More verbose (more detailed trace)
 
== Examples ==
\$perl $0 -h 192.168.0.1 -e 100-200 -v
\tTo check extensions range from 100 to 200 (with verbose mode)
\$perl $0 -h 192.168.0.1 -e 100-200 -v
\tTo check several ranges
\$perl $0 -h 192.168.0.1,192.168.2.0/24.192.168.3.1-192.168.50.200
\tTo check extensions range from user100 to user200
\$perl $0 -h 192.168.0.0/24 -e 100 -r 5060-5080 -vv
\tTo check extension 100 with destination port between 5060 and 5080 (with packages info)

};
 
    exit 1;
}
 
init();
