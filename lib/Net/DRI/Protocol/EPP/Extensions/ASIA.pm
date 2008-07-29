## Domain Registry Interface, ASIA EPP extensions
##
## Copyright (c) 2007,2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::ASIA;

use strict;

use Net::DRI::Data::Contact::ASIA;
use base qw/Net::DRI::Protocol::EPP/;

our $VERSION=do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::ASIA - ASIA EPP extensions for Net::DRI

=head1 DESCRIPTION

Please see the README file for details.

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

E<lt>http://www.dotandco.com/services/software/Net-DRI/E<gt> and
E<lt>http://oss.bsdprojects.net/projects/netdri/E<gt>

=head1 AUTHOR

Tonnerre Lombard E<lt>tonnerre.lombard@sygroup.chE<gt>

=head1 COPYRIGHT

Copyright (c) 2007,2008 Tonnerre Lombard <tonnerre.lombard@sygroup.ch>.
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
 my ($c,$drd,$version,$extrah,$defproduct)=@_;
 my %e=map { $_ => 1 } (defined($extrah)? (ref($extrah)? @$extrah : ($extrah)) : ());

 if (exists($e{':full'})) ## useful shortcut, modeled after Perl itself
 {
  delete($e{':full'});
  $e{'Net::DRI::Protocol::EPP::Extensions::GracePeriod'}=1;
  $e{'Net::DRI::Protocol::EPP::Extensions::ASIA::IPR'}=1;
  $e{'Net::DRI::Protocol::EPP::Extensions::ASIA::CED'}=1;
 }

 my $self=$c->SUPER::new($drd,$version,[keys(%e)]);
 $self->ns({ asia => ['urn:afilias:params:xml:ns:asia-1.0','asia-1.0.xsd'],
             ipr  => ['urn:afilias:params:xml:ns:ipr-1.0','ipr-1.0.xsd'],  
           });
 $self->factories('contact',sub { return Net::DRI::Data::Contact::ASIA->new(@_); }) if (exists($e{'Net::DRI::Protocol::EPP::Extensions::ASIA::CED'}));
 $self->capabilities('domain_update','url',['set']);
 $self->capabilities('domain_update','contact',['add','set','del']);
 return $self;
}

####################################################################################################
1;
