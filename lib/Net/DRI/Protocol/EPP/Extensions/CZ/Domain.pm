## Domain Registry Interface, CZ domain transactions extension
##
## Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
##                    All rights reserved.
##
## This file is part of Net::DRI
##
## Net::DRI is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## See the LICENSE file that comes with this distribution for more details.
#
# 
#
####################################################################################################

package Net::DRI::Protocol::EPP::Extensions::CZ::Domain;

use strict;

use Net::DRI::Util;
#use Net::DRI::Protocol::EPP::Core::Domain;

our $VERSION = do { my @r = ( q$Revision: 1.2 $ =~ /\d+/g ); sprintf( "%d" . ".%02d" x $#r, @r ); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::CZ::Domain - .CZ Domain extension

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>development@sygroup.chE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://oss.bsdprojects.net/projects/netdri/E<gt>

=head1 AUTHOR

Tonnerre Lombard, E<lt>tonnerre.lombard@sygroup.chE<gt>

=head1 COPYRIGHT

Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub register_commands
{
       my ($class, $version) = @_;
       my %tmp = (
		info		=> [ \&info, \&info_parse ],
		create		=> [ \&create, undef ],
		update		=> [ \&update ],
       );
      
       return { 'domain' => \%tmp };
}

##################################################################################################

sub build_command
{
	my ($msg, $command, $domain, $domainattr) = @_;
	my @dom = (ref($domain)) ? @$domain : ($domain);
	Net::DRI::Exception->die(1, 'protocol/EPP', 2, "Domain name needed")
		unless @dom;

	foreach my $d (@dom)
	{
		Net::DRI::Exception->die(1, 'protocol/EPP', 2,
			'Domain name needed') unless (defined($d) && $d);
		Net::DRI::Exception->die(1, 'protocol/EPP', 10,
			'Invalid domain name: ' . $d)
			unless (Net::DRI::Util::is_hostname($d));
	}

	my $tcommand = (ref($command)) ? $command->[0] : $command;
	my @ns = @{$msg->ns->{domain}};
	$msg->command([$command, 'domain:' . $tcommand,
		sprintf('xmlns:domain="%s" xsi:schemaLocation="%s %s"',
			$ns[0], $ns[0], $ns[1])]);

	my @d = map { ['domain:name', $_, $domainattr] } @dom;
	return @d;
}

sub build_authinfo
{
	my $rauth = shift;
	return ['domain:authInfo', $rauth->{pw}];
}

sub build_period
{
	my $dtd = shift; ## DateTime::Duration
	## all values are integral, but may be negative
	my ($y, $m) = $dtd->in_units('years', 'months');
	($y, $m) = (0, $m + 12 * $y) if ($y && $m);
	my ($v, $u);

	if ($y)
	{
		Net::DRI::Exception::usererr_invalid_parameters('years must ' .
			'be between 1 and 99') unless ($y >= 1 && $y <= 99);
		$v = $y;
		$u = 'y';
	}
	else
	{
		Net::DRI::Exception::usererr_invalid_parameters('months must ' .
			'be between 1 and 99') unless ($m >= 1 && $m <= 99);
		$v = $m;
		$u = 'm';
	}
 
	return ['domain:period', $v, {'unit' => $u}];
}


##################################################################################################


########### Query commands

sub verify_rd
{
	my ($rd, $key) = @_;
	return 0 unless (defined($key) && $key);
	return 0 unless (defined($rd) && (ref($rd) eq 'HASH') &&
		exists($rd->{$key}) && defined($rd->{$key}));
	return 1;
}


sub info
{
	my ($epp, $domain, $rd) = @_;
	my $mes = $epp->message();
	my @d = build_command($mes, 'info', $domain);
	push(@d, build_authinfo($rd->{auth}))
		if (verify_rd($rd, 'auth') && (ref($rd->{auth}) eq 'HASH'));
	$mes->command_body(\@d);
}

sub info_parse
{
	my ($po, $otype, $oaction, $oname, $rinfo) = @_;
	my $mes = $po->message();
	return unless $mes->is_success();
	my $infdata = $mes->get_content('infData', $mes->ns('domain'));
	return unless $infdata;
	my (@s, @host, $ns);
	my $cs = Net::DRI::Data::ContactSet->new();
	my $cf = $po->factories()->{contact};
	my $c = $infdata->getFirstChild();

	while ($c)
	{
		my $name = $c->localname() || $c->nodeName();
		next unless $name;
		if ($name eq 'name')
		{
			$oname = lc($c->getFirstChild()->getData());
			$rinfo->{domain}->{$oname}->{action} = 'info';
			$rinfo->{domain}->{$oname}->{exist} = 1;
		}
		elsif ($name eq 'roid')
		{
			$rinfo->{domain}->{$oname}->{roid} =
				$c->getFirstChild()->getData();
		}
		elsif ($name eq 'status')
		{
			push(@s, Net::DRI::Protocol::EPP::parse_status($c));
		}
		elsif ($name =~ /^(registrant|admin)$/)
		{
			$cs->set($cf->()->srid($c->getFirstChild()->getData()),
				$1);
		}
		elsif ($name eq 'ns')
		{
			$ns = Net::DRI::Data::Hosts->new() if (!$ns);
			$ns->add($c->getFirstChild()->getData());
		}
		elsif ($name eq 'host')
		{
			push(@host, $c->getFirstChild()->getData());
		}
		elsif ($name =~ m/^(clID|crID|upID)$/)
		{
			$rinfo->{domain}->{$oname}->{$1} =
				$c->getFirstChild()->getData();
		}
		elsif ($name =~ m/^(crDate|upDate|trDate|exDate)$/)
		{
			$rinfo->{domain}->{$oname}->{$1} =
				DateTime::Format::ISO8601->new()->
					parse_datetime($c->getFirstChild()->
						getData());
		}
		elsif ($name eq 'authInfo')
		{
			my $pw = $c->getFirstChild()->getData();
			$rinfo->{domain}->{$oname}->{auth} =
				{pw => ($pw ? $pw : undef) };
		}

		$c = $c->getNextSibling();
	}

	$rinfo->{domain}->{$oname}->{contact} = $cs;
	$rinfo->{domain}->{$oname}->{status} = $po->
		create_local_object('status')->add(@s);
	$rinfo->{domain}->{$oname}->{host} = Net::DRI::Data::Hosts->
		new_set(@host) if (@host);
	$rinfo->{domain}->{$oname}->{ns} = $ns if ($ns);
}

############ Transform commands

sub create
{
	my ($epp, $domain, $rd) = @_;
	my $mes = $epp->message();
	my @d = build_command($mes, 'create', $domain);
	my $def = $epp->default_parameters();
 
	if ($def && (ref($def) eq 'HASH') && exists($def->{domain_create}) &&
		(ref($def->{domain_create}) eq 'HASH'))
	{
		$rd = {} unless ($rd && (ref($rd) eq 'HASH') && keys(%$rd));

		while (my ($k, $v) = each(%{$def->{domain_create}}))
		{
			next if exists($rd->{$k});
			$rd->{$k} = $v;
		}
	}

	## Period, OPTIONAL
	if (verify_rd($rd, 'duration'))
	{
		my $period = $rd->{duration};
		Net::DRI::Util::check_isa($period, 'DateTime::Duration');
		push(@d, build_period($period));
	}

	## XXX: Nameserver sets, OPTIONAL

	## Contacts, all OPTIONAL
	if (verify_rd($rd, 'contact') && UNIVERSAL::isa($rd->{contact},
		'Net::DRI::Data::ContactSet'))
	{
		my $cs = $rd->{contact};
		push(@d, build_contacts($cs));
	}

	## AuthInfo
	Net::DRI::Exception::usererr_insufficient_parameters('authInfo is ' .
		'mandatory')
		unless (verify_rd($rd, 'auth') && (ref($rd->{auth}) eq 'HASH'));
	push(@d, build_authinfo($rd->{auth}));
	$mes->command_body(\@d);
}

sub build_contacts
{
	my $cs = shift;
	my @d;

	foreach my $t (sort { $b cmp $a } $cs->types())
	{
		my @o = $cs->get($t);
		push(@d, map { ['domain:' . $t, $_->srid()] } @o);
	}

	return @d;
}

sub update
{
	my ($epp, $domain, $todo) = @_;
	my $mes = $epp->message();

	Net::DRI::Exception::usererr_invalid_parameters($todo .
		' must be a Net::DRI::Data::Changes object') unless
		($todo && UNIVERSAL::isa($todo, 'Net::DRI::Data::Changes'));

	if ((grep { ! /^(?:add|del)$/ } $todo->types('ns')) ||
		(grep { ! /^(?:add|del)$/ } $todo->types('status')) ||
		(grep { ! /^(?:add|del)$/ } $todo->types('contact')) ||
		(grep { ! /^set$/ } $todo->types('auth')))
	{
		Net::DRI::Exception->die(0, 'protocol/EPP', 11,
			'Only ns/status/contact add/del or registrant/' .
			'authinfo set available for domain');
	}

	my @d = build_command($mes, 'update', $domain);

	my $nsadd = $todo->add('ns');
	my $nsdel = $todo->del('ns');
	my $sadd = $todo->add('status');
	my $sdel = $todo->del('status');
	my $cadd = $todo->add('contact');
	my $cdel = $todo->del('contact');
	my (@add, @del);

	push(@add, build_ns($epp, $nsadd, $domain))		if ($nsadd &&
		!$nsadd->is_empty());
	push(@add, build_contacts($cadd))			if ($cadd);
	push(@add, $sadd->build_xml('domain:status', 'core'))	if ($sadd);
	push(@del, build_ns($epp, $nsdel, $domain))		if ($nsdel &&
		!$nsdel->is_empty());
	push(@del, build_contacts($cdel))			if ($cdel);
	push(@del, $sdel->build_xml('domain:status', 'core'))	if ($sdel);

	push(@d, ['domain:add', @add]) if (@add);
	push(@d, ['domain:rem', @del]) if (@del);

	my $chg = $todo->set('registrant');
	my @chg;
	push(@chg, ['domain:registrant', $chg->srid()])
		if ($chg && ref($chg) && UNIVERSAL::can($chg, 'srid'));
	$chg = $todo->set('auth');
	push(@chg, build_authinfo($chg)) if ($chg && ref($chg));
	push(@d, ['domain:chg', @chg]) if (@chg);

	## RFC3731 is ambigous
	## The text says that domain:add domain:rem or domain:chg must be there,
	## but the XML schema has minOccurs=0 for each of them
	## The consensus on the mailing-list is that the XML schema is normative
	## However some server might follow the text, in which case we will need the following lines
	## which were removed for Net::DRI 0.16
	## my $hasext=(grep { ! /^(?:ns|status|contact|registrant|authinfo)$/ } $todo->types())? 1 : 0;
	## push(@d, ['domain:chg']) if ($hasext && !@chg);
 
	$mes->command_body(\@d);
}

####################################################################################################
1;
