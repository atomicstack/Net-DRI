## Domain Registry Interface, NORID (.NO) EPP extensions
##
## Copyright (c) 2008 UNINETT Norid AS, E<lt>http://www.norid.noE<gt>,
##                    Trond Haugen E<lt>info@norid.noE<gt>
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

package Net::DRI::Protocol::EPP::Extensions::NO;

use strict;

use base qw/Net::DRI::Protocol::EPP/;

use Net::DRI::Data::Contact::NO;

our $VERSION = do { my @r = ( q$Revision: 1.3 $ =~ /\d+/gmx ); sprintf( "%d" . ".%02d" x $#r, @r ); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::NO - .NO EPP extensions for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt>

=head1 AUTHOR

Trond Haugen, E<lt>info@norid.noE<gt>

=head1 COPYRIGHT

Copyright (c) 2008 UNINETT Norid AS, E<lt>http://www.norid.noE<gt>,
Trond Haugen E<lt>info@norid.noE<gt>
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################
sub new {
    my ( $c, $drd, $version, $extrah ) = @_;
    my %e = map { $_ => 1 }
        ( defined($extrah) ? ( ref($extrah) ? @$extrah : ($extrah) ) : () );

    $e{'Net::DRI::Protocol::EPP::Extensions::NO::Domain'}  = 1;
    $e{'Net::DRI::Protocol::EPP::Extensions::NO::Contact'} = 1;
    $e{'Net::DRI::Protocol::EPP::Extensions::NO::Host'}    = 1;
    $e{'Net::DRI::Protocol::EPP::Extensions::NO::Result'}  = 1;
    $e{'Net::DRI::Protocol::EPP::Extensions::NO::Message'} = 1;

    my $self = $c->SUPER::new( $drd, $version, [ keys(%e) ] );
    $self->ns({ no_contact => [ 'http://www.norid.no/xsd/no-ext-contact-1.0','no-ext-contact-1.0.xsd' ],
                no_domain  => [ 'http://www.norid.no/xsd/no-ext-domain-1.0','no-ext-domain-1.0.xsd' ],
                no_host    => [ 'http://www.norid.no/xsd/no-ext-host-1.0','no-ext-host-1.0.xsd' ],
                no_result  => [ 'http://www.norid.no/xsd/no-ext-result-1.0','no-ext-result-1.0.xsd' ],
                no_epp     => [ 'http://www.norid.no/xsd/no-ext-epp-1.0','no-ext-epp-1.0.xsd' ],
             });


    foreach my $o (qw/mobilephone identity xdisclose/)  { $self->capabilities('contact_update',$o,['set']); }
    foreach my $o (qw/organization rolecontact xemail/) { $self->capabilities('contact_update',$o,['add','del']); }
    $self->capabilities('host_update','contact',['set']);
    $self->factories('contact',sub { return Net::DRI::Data::Contact::NO->new(); });

    return $self;
}

####################################################################################################
1;
