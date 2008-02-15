## Domain Registry Interface, Gandi Web Services Domain commands
##
## Copyright (c) 2008 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::Gandi::WS::Domain;

use strict;

use DateTime::Format::ISO8601;

use Net::DRI::Exception;
use Net::DRI::Util;
use Net::DRI::Data::ContactSet;
use Net::DRI::Data::Contact;
use Net::DRI::Data::StatusList;

our $VERSION=do { my @r=(q$Revision: 1.1 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::Gandi::WS::Domain - Gandi Web Services Domain commands for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt>

=head1 AUTHOR

Patrick Mevzek, E<lt>netdri@dotandco.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2008 Patrick Mevzek <netdri@dotandco.com>.
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
 my ($class,$version)=@_;
 my %tmp=(
		info => [\&info, \&info_parse ],
	  );

 return { 'domain' => \%tmp };
}

sub build_msg
{
 my ($msg,$command,$domain)=@_;
 Net::DRI::Exception->die(1,'protocol/gandi/ws',2,'Domain name needed') unless defined($domain) && $domain;
 Net::DRI::Exception->die(1,'protocol/gandi/ws',10,'Invalid domain name') unless Net::DRI::Util::is_hostname($domain);

 $msg->method($command) if defined($command);
}

sub info
{
 my ($po,$domain)=@_;
 my $msg=$po->message();
 build_msg($msg,'domain_info',$domain);
 $msg->params([$domain]);
}

sub info_parse
{
  my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $r=$mes->result();
 Net::DRI::Exception->die(1,'protocol/gandi/ws',1,'Unexpected reply for domain_info: '.$r) unless (ref($r) eq 'HASH');

 my %r=%$r;
 $rinfo->{domain}->{$oname}->{action}='info';
 $rinfo->{domain}->{$oname}->{exist}=1;
 my $pd=DateTime::Format::ISO8601->new();
 my %d=(registry_creation_date => 'crDate', registry_last_update => 'upDate', registry_expiration_date => 'exDate', registrar_creation_date => 'trDate');
 while (my ($k,$v)=each(%d))
 {
  next unless exists($r{$k});
  $rinfo->{domain}->{$oname}->{$v}=$pd->parse_datetime($r{$k});
 }
 my %c=(owner_handle => 'registrant', admin_handle => 'admin', tech_handle => 'tech', billing_handle => 'billing');
 my $cs=Net::DRI::Data::ContactSet->new();
 while (my ($k,$v)=each(%d))
 {
  next unless exists($r{$k});
  my $c=Net::DRI::Data::Contact->new()->srid($r{$k});
  $cs->add($c,$v);
 }
 $rinfo->{domain}->{$oname}->{contact}=$cs;
 $rinfo->{domain}->{$oname}->{auth}={pw => $r{authorization_code}};

 if ($r{locked})
 {
  $rinfo->{domain}->{$oname}->{status}=Net::DRI::Data::StatusList->new()->add('clientTransferProhibited'); ## ?
 } else
 {
  $rinfo->{domain}->{$oname}->{status}=Net::DRI::Data::StatusList->new()->add('ok');
 }

 ## And what about nameservers ? No information in documentation, only separate functions for that: domain_ns_*
 # $rinfo->{domain}->{$oname}->{ns}=??
}

####################################################################################################
1;