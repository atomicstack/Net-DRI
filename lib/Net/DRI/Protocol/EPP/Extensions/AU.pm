## Domain Registry Interface, .AU EPP extensions
##
## Copyright (c) 2007,2008 Distribute.IT Pty Ltd, www.distributeit.com.au, Rony Meyer <perl@spot-light.ch>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::AU;

use strict;

use base qw/Net::DRI::Protocol::EPP/;

our $VERSION=do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::AU - .AU EPP extensions for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt>

=head1 AUTHOR

Rony Meyer, E<lt>perl@spot-light.chE<gt>
 
=head1 COPYRIGHT

Copyright (c) 2007,2008 Distribute.IT Pty Ltd, E<lt>http://www.distributeit.com.auE<gt>, Rony Meyer <perl@spot-light.ch>.
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
 my ($c,$drd,$version,$extrah)=@_;
 my %e=map { $_ => 1 } (defined($extrah)? (ref($extrah)? @$extrah : ($extrah)) : ());

 $e{'Net::DRI::Protocol::EPP::Extensions::AU::Domain'}=1;

 my $self=$c->SUPER::new($drd,$version,[keys(%e)]);
 $self->ns({auext   => ['urn:au:params:xml:ns:auext-1.0','auext-1.0.xsd'],
            auextnew=> ['urn:X-au:params:xml:ns:auext-1.1','auext-1.1.xsd'],
          });
 $self->capabilities('domain_update','maintainer_url',['set']);
 return $self;
}

####################################################################################################
1;
