## Domain Registry Interface, .LU policy from DocRegistrar-2.0.6.pdf
##
## Copyright (c) 2007,2008 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::DRD::LU;

use strict;
use base qw/Net::DRI::DRD/;

use Net::DRI::Util;

our $VERSION=do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::DRD::LU - .LU policies for Net::DRI

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

Copyright (c) 2007,2008 Patrick Mevzek <netdri@dotandco.com>.
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
 my $class=shift;
 my $self=$class->SUPER::new(@_);
 $self->{info}->{host_as_attr}=0;
 $self->{info}->{contact_i18n}=1; ## LOC only
 bless($self,$class);
 return $self;
}

sub periods  { return; } ## registry does not expect any duration at all
sub name     { return 'DNSLU'; }
sub tlds     { return ('lu'); }
sub object_types { return ('domain','contact','ns'); }

sub transport_protocol_compatible
{
 my ($self,$to,$po)=@_;
 my $pn=$po->name();
 my $tn=$to->name();

 return 1 if (($pn eq 'EPP') && ($tn eq 'socket_inet'));
 return 1 if (($pn eq 'Whois') && ($tn eq 'socket_inet'));
 return;
}

sub transport_protocol_default
{
 my ($drd,$ndr,$type,$ta,$pa)=@_;
 $type='epp' if (!defined($type) || ref($type));
 return Net::DRI::DRD::_transport_protocol_default_epp('Net::DRI::Protocol::EPP::Extensions::LU',$ta,$pa) if ($type eq 'epp');
 return ('Net::DRI::Transport::Socket',[{%Net::DRI::DRD::PROTOCOL_DEFAULT_WHOIS,remote_host=>'whois.dns.lu'}],'Net::DRI::Protocol::Whois',[]) if (lc($type) eq 'whois');
}

####################################################################################################

sub verify_name_domain
{
 my ($self,$ndr,$domain,$op)=@_;
 ($domain,$op)=($ndr,$domain) unless (defined($ndr) && $ndr && (ref($ndr) eq 'Net::DRI::Registry'));

 my $r=$self->SUPER::check_name($domain,1);
 return $r if ($r);
 return 10 unless $self->is_my_tld($domain);
 my ($d,undef)=split(/\./,$domain);
 return 11 if (length($d)<3 || (substr($d,2,2) eq '--'));
 return 0;
}

sub verify_duration_transfer
{
 my ($self,$ndr,$duration,$domain,$op)=@_;
 ($duration,$domain,$op)=($ndr,$duration,$domain) unless (defined($ndr) && $ndr && (ref($ndr) eq 'Net::DRI::Registry'));

 return 0 unless ($op eq 'start'); ## we are not interested by other cases, they are always OK
 return 0;
}

sub domain_operation_needs_is_mine
{
 my ($self,$ndr,$domain,$op)=@_;
 ($domain,$op)=($ndr,$domain) unless (defined($ndr) && $ndr && (ref($ndr) eq 'Net::DRI::Registry'));

 return unless defined($op);

 return 1 if ($op=~m/^(?:update|delete)$/);
 return 0 if ($op eq 'transfer');
 return;
}

sub domain_status_allows
{
 my ($self,$ndr,$domain,$what,$rd)=@_;

 return 0 unless ($what=~m/^(?:delete|update|transfer|renew|trade|transfer-trade|transfer-restore)$/);
 my $s=$self->domain_current_status($ndr,$domain,$rd);
 return 0 unless (defined($s));

 return !$s->is_pending() && $s->can_delete()   if ($what eq 'delete');
 return !$s->is_pending() && $s->can_update()   if ($what eq 'update'); ## no pendingCreate pendingUpdate pendingDelete
 return $s->can_transfer() if ($what eq 'transfer');
 return 0                  if ($what eq 'renew');
 return $s->has_not('serverTradeProhibited','pendingCreate','pendingDelete') if ($what eq 'trade');
 return $s->has_not('serverTransferProhibited','serverTradeProhibited') if ($what eq 'transfer-trade');
 return $s->has_not('serverTransferProhibited','serverRestoreProhibited') && $s->has_any('pendingDelete') if ($what eq 'transfer-restore');
 return 0; ## failsafe
}

sub domain_renew           { Net::DRI::Exception->die(0,'DRD',4,'No domain renew available in .LU'); }
sub domain_transfer_accept { Net::DRI::Exception->die(0,'DRD',4,'No approve transfer approve available in .LU'); }
sub domain_transfer_refuse { Net::DRI::Exception->die(0,'DRD',4,'No approve transfer reject in .LU'); }

sub contact_transfer_start  { Net::DRI::Exception->die(0,'DRD',4,'No contact transfer request available in .LU'); }
sub contact_transfer_stop   { Net::DRI::Exception->die(0,'DRD',4,'No contact transfer cancel available in .LU'); }
sub contact_transfer_query  { Net::DRI::Exception->die(0,'DRD',4,'No contact transfer query available in .LU'); }
sub contact_transfer_accept { Net::DRI::Exception->die(0,'DRD',4,'No contact transfer approve available in .LU'); }
sub contact_transfer_refuse { Net::DRI::Exception->die(0,'DRD',4,'No contact transfer reject in .LU'); }

####################################################################################################
1;
