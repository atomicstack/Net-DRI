## Domain Registry Interface, .PRO policies
##
## Copyright (c) 2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>
##		      All rights reserved.
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

package Net::DRI::DRD::PRO;

use strict;
use base qw/Net::DRI::DRD/;

use Net::DRI::DRD::ICANN;
use DateTime::Duration;

our $VERSION=do { my @r=(q$Revision: 1.1 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::DRD::PRO - .PRO policies for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>development@sygroup.chE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.bsdprojects.net/project/netdri/E<gt>

=head1 AUTHOR

Tonnerre Lombard, E<lt>tonnerre.lombard@sygroup.chE<gt>,
Alexander Biehl, E<lt>info@hexonet.netE<gt>, HEXONET Support GmbH,
E<lt>http://www.hexonet.net/E<gt>.

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

sub new
{
 my $class = shift;
 my $self = $class->SUPER::new(@_);
 $self->{info}->{host_as_attr} = 0;

 bless($self, $class);
 return $self;
}

sub periods  { return map { DateTime::Duration->new(years => $_) } (1..10); }
sub name     { return 'RegistryPro'; }
sub tlds     { return qw/pro law.pro jur.pro bar.pro med.pro cpa.pro aca.pro eng.pro/; }
sub object_types { return ('domain','contact','ns','av'); }

sub transport_protocol_compatible
{
 my ($self, $to, $po) = @_;
 my $pn = $po->name();
 my $pv = $po->version();
 my $tn = $to->name();

 return 1 if (($pn eq 'EPP') && ($tn eq 'socket_inet'));
 return;
}

sub transport_protocol_default
{
 my ($drd, $ndr, $type, $ta, $pa) = @_;
 $type = 'epp' if (!defined($type) || ref($type));
 return Net::DRI::DRD::_transport_protocol_default_epp('Net::DRI::Protocol::EPP::Extensions::PRO', $ta, $pa) if ($type eq 'epp');
}

####################################################################################################

sub verify_name_domain
{
 my ($self, $ndr, $domain, $op) = @_;
 ($domain, $op) = ($ndr, $domain)
	unless (defined($ndr) && $ndr && (ref($ndr) eq 'Net::DRI::Registry'));

 my $r = $self->SUPER::check_name($domain, [1,2]);
 return $r if ($r);
 return 10 unless $self->is_my_tld($domain);
 return 11 if Net::DRI::DRD::ICANN::is_reserved_name($domain, $op);

 return 0;
}

sub domain_operation_needs_is_mine
{
 my ($self, $ndr, $domain, $op) = @_;
 ($domain, $op) = ($ndr, $domain)
	unless (defined($ndr) && $ndr && (ref($ndr) eq 'Net::DRI::Registry'));

 return unless defined($op);

 return 1 if ($op =~ m/^(?:renew|update|delete)$/);
 return 0 if ($op eq 'transfer');
 return;
}

####################################################################################################
## TODO : $av should be checked here to be syntaxically correct before doing process()

sub av_create { my ($self,$ndr,$av,$ep)=@_; return $ndr->process('av','create',[$av,$ep]); }
sub av_check  { my ($self,$ndr,$av,$ep)=@_; return $ndr->process('av','check',[$av,$ep]); }
sub av_info   { my ($self,$ndr,$av,$ep)=@_; return $ndr->process('av','info',[$av,$ep]); }

####################################################################################################
1;
