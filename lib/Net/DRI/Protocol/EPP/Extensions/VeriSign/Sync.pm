## Domain Registry Interface, EPP Sync aka ConsoliDate (draft-hollenbeck-epp-sync-01)
##
## Copyright (c) 2006 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::VeriSign::Sync;

use strict;

use Net::DRI::Util;
use Net::DRI::Exception;
use Net::DRI::Protocol::EPP::Core::Domain;

our $VERSION=do { my @r=(q$Revision: 1.1 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::VeriSign::Sync - EPP Sync commands (draft-hollenbeck-epp-sync-01) for Net::DRI

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

Copyright (c) 2006 Patrick Mevzek <netdri@dotandco.com>.
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
           update => [ \&update, undef ],
         );

 return { 'domain' => \%tmp };
}

sub capabilities_add
{
 return { 'domain_update' => { 'sync' => ['set'] }};
}

####################################################################################################

############ Transform commands

sub update
{
 my ($epp,$domain,$todo)=@_;
 my $mes=$epp->message();

 my $sync=$todo->set('sync');
 return unless (defined($sync) && $sync);

 my $date;
 if (ref($sync))
 {
  Net::DRI::Util::check_isa($sync,'DateTime');
  $date=$sync->strftime('--%m-%d');  
 } else
 {
  Net::DRI::Exception::usererr_invalid_parameters('Sync date must be of type XML Schema gMonthDay') unless ($sync=~m/^(?:--)?(\d{2}-\d{2})$/);
  $date="--$1";
 }

 Net::DRI::Exception::usererr_invalid_parameters('Sync operation can not be mixed with other domain changes') if (grep { $_ ne 'sync' } $todo->types());

 my $eid=$mes->command_extension_register('sync:update','xmlns:sync="http://www.verisign.com/epp/sync-1.0" xsi:schemaLocation="http://www.verisign.com/epp/sync-1.0 sync-1.0.xsd"');
 $mes->command_extension($eid,['sync:expMonthDay',$date]);

 ## This part is not clear
 ## The draft (march 2005), says one empty domaine:add/rem/chg must be there
 ## But EPP core RFC are being updated, to say these nodes are not necessary for extensions
 ## http://www.cafax.se/ietf-provreg/maillist/2005-09/msg00007.html (september 2005)
 my @d=Net::DRI::Protocol::EPP::Core::Domain::build_command($mes,'update',$domain);
 push @d,['domain:chg'];
 $mes->command_body(\@d);
}

####################################################################################################
1;