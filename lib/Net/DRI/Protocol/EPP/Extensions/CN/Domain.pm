## Domain Registry Interface, CN domain transactions extension
##
## Copyright (c) 2006,2007 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Extensions::CN::Domain;

use strict;

use Net::DRI::Util;
#use Net::DRI::Protocol::EPP::Core::Domain;

our $VERSION = do { my @r = ( q$Revision: 1.2 $ =~ /\d+/g ); sprintf( "%d" . ".%02d" x $#r, @r ); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Extensions::CN::Domain - .CN Domain extension

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

Copyright (c) 2006,2007 Patrick Mevzek <netdri@dotandco.com>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub register_commands {
       my ( $class, $version ) = @_;
       my %tmp=(
		check		=> [ undef, \&check_parse ],
		info		=> [ \&info, \&info_parse ],
		transfer_query	=> [ \&transfer_query, undef ],
		create		=> [ \&create, undef ],
		renew		=> [ undef, \&renew_parse ],
		transfer_request=> [ \&transfer_request, undef ],
		transfer_cancel	=> [ \&transfer_cancel,undef ],
		transfer_answer	=> [ \&transfer_answer,undef ],
		update		=> [ \&update ],
               );
      
       $tmp{check_multi}=$tmp{check};

       return { 'domain' => \%tmp };
}

##################################################################################################

sub build_command
{
 my ($msg,$command,$domain,$domainattr)=@_;
 my @dom=(ref($domain))? @$domain : ($domain);
 Net::DRI::Exception->die(1,'protocol/EPP',2,"Domain name needed") unless @dom;
 foreach my $d (@dom)
 {
  Net::DRI::Exception->die(1,'protocol/EPP',2,'Domain name needed') unless defined($d) && $d;
  Net::DRI::Exception->die(1,'protocol/EPP',10,'Invalid domain name: '.$d) unless Net::DRI::Util::is_hostname($d);
 }

 my $tcommand=(ref($command))? $command->[0] : $command;
 my @ns=@{$msg->ns->{domain}};
 $msg->command([$command,'domain:'.$tcommand,sprintf('xmlns:domain="%s" xsi:schemaLocation="%s %s"',$ns[0],$ns[0],$ns[1])]);


 my @d=map { ['domain:name',$_,$domainattr] } @dom;
 return @d;
}

sub build_authinfo
{
 my $rauth=shift;
 return ['domain:authInfo',$rauth->{pw}, {type => 'pw'}];
}

sub build_period
{
 my $dtd=shift; ## DateTime::Duration
 my ($y,$m)=$dtd->in_units('years','months'); ## all values are integral, but may be negative
 ($y,$m)=(0,$m+12*$y) if ($y && $m);
 my ($v,$u);
 if ($y)
 {
  Net::DRI::Exception::usererr_invalid_parameters("years must be between 1 and 99") unless ($y >= 1 && $y <= 99);
  $v=$y;
  $u='y';
 } else
 {
  Net::DRI::Exception::usererr_invalid_parameters("months must be between 1 and 99") unless ($m >= 1 && $m <= 99);
  $v=$m;
  $u='m';
 }
 
 return ['domain:period',$v,{'unit' => $u}];
}


##################################################################################################


########### Query commands

sub check_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $chkdata=$mes->get_content('chkData',$mes->ns('domain'));
 return unless $chkdata;
 foreach my $cd ($chkdata->getElementsByTagNameNS($mes->ns('domain'),'cd'))
 {
  my $domain;
    $domain=lc($cd->getFirstChild()->getData());
    $rinfo->{domain}->{$domain}->{action}='check';
    if ($cd->getAttribute('x') eq '+') {
       $rinfo->{domain}->{$domain}->{exist}=1;
    } else {
       $rinfo->{domain}->{$domain}->{exist}=0;
    }
 }
}

sub verify_rd
{
 my ($rd,$key)=@_;
 return 0 unless (defined($key) && $key);
 return 0 unless (defined($rd) && (ref($rd) eq 'HASH') && exists($rd->{$key}) && defined($rd->{$key}));
 return 1;
}


sub info
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,'info',$domain);
 push @d,build_authinfo($rd->{auth}) if (verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 $mes->command_body(\@d);
}



sub info_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();
 my $infdata=$mes->get_content('infData',$mes->ns('domain'));
 return unless $infdata;
 my (@s,@host,$ns);
 my $cs=Net::DRI::Data::ContactSet->new();
 my $cf=$po->factories()->{contact};
 my $c=$infdata->getFirstChild();
 while ($c)
 {
  my $name=$c->localname() || $c->nodeName();
  next unless $name;
  if ($name eq 'name')
  {
   $oname=lc($c->getFirstChild()->getData());
   $rinfo->{domain}->{$oname}->{action}='info';
   $rinfo->{domain}->{$oname}->{exist}=1;
  } elsif ($name eq 'roid')
  {
   $rinfo->{domain}->{$oname}->{roid}=$c->getFirstChild()->getData();
  } elsif ($name eq 'status')
  {
   push @s,Net::DRI::Protocol::EPP::parse_status($c);
  } elsif ($name eq 'registrant')
  {
   $cs->set($cf->()->srid($c->getFirstChild()->getData()),'registrant');
  } elsif ($name eq 'contact')
  {
   $cs->add($cf->()->srid($c->getFirstChild()->getData()),$c->getAttribute('type'));
  } elsif ($name eq 'ns')
  {
       $ns=Net::DRI::Data::Hosts->new() if !$ns;
       $ns->add($c->getFirstChild()->getData());
  } elsif ($name eq 'host')
  {
   push @host,$c->getFirstChild()->getData();
  } elsif ($name=~m/^(clID|crID|upID)$/)
  {
   $rinfo->{domain}->{$oname}->{$1}=$c->getFirstChild()->getData();
  } elsif ($name=~m/^(crDate|upDate|trDate|exDate)$/)
  {
   $rinfo->{domain}->{$oname}->{$1}=DateTime::Format::ISO8601->new()->parse_datetime($c->getFirstChild()->getData());
  } elsif ($name eq 'authInfo')
  {
   my $pw=$c->getFirstChild()->getData();
   $rinfo->{domain}->{$oname}->{auth}={pw => ($pw)? $pw : undef };
  }
  $c=$c->getNextSibling();
 }

 $rinfo->{domain}->{$oname}->{contact}=$cs;
 $rinfo->{domain}->{$oname}->{status}=$po->create_local_object('status')->add(@s);
 $rinfo->{domain}->{$oname}->{host}=Net::DRI::Data::Hosts->new_set(@host) if @host;
 $rinfo->{domain}->{$oname}->{ns}=$ns if $ns;
}



sub transfer_query
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,['transfer',{'op'=>'query'}],$domain);
 push @d,build_authinfo($rd->{auth}) if (verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 $mes->command_body(\@d);
}


############ Transform commands

sub create
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,'create',$domain);
 
 my $def=$epp->default_parameters();
 if ($def && (ref($def) eq 'HASH') && exists($def->{domain_create}) && (ref($def->{domain_create}) eq 'HASH'))
 {
  $rd={} unless ($rd && (ref($rd) eq 'HASH') && keys(%$rd));
  while(my ($k,$v)=each(%{$def->{domain_create}}))
  {
   next if exists($rd->{$k});
   $rd->{$k}=$v;
  }
 }

 ## Period, OPTIONAL
 if (verify_rd($rd,'duration'))
 {
  my $period=$rd->{duration};
  Net::DRI::Util::check_isa($period,'DateTime::Duration');
  push @d,build_period($period);
 }

 ## Nameservers, OPTIONAL
 push @d,build_ns($epp,$rd->{ns},$domain) if (verify_rd($rd,'ns') && UNIVERSAL::isa($rd->{ns},'Net::DRI::Data::Hosts') && !$rd->{ns}->is_empty());

 ## Contacts, all OPTIONAL
 if (verify_rd($rd,'contact') && UNIVERSAL::isa($rd->{contact},'Net::DRI::Data::ContactSet'))
 {
  my $cs=$rd->{contact};
  my @o=$cs->get('registrant');
  push @d,['domain:registrant',$o[0]->srid()] if (@o);
  push @d,build_contact_noregistrant($cs);
 }

 ## AuthInfo
 Net::DRI::Exception::usererr_insufficient_parameters("authInfo is mandatory") unless (verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 push @d,build_authinfo($rd->{auth});
 $mes->command_body(\@d);
}

sub build_contact_noregistrant
{
 my $cs=shift;
 my @d;
 foreach my $t (sort($cs->types()))
 {
  next if ($t eq 'registrant');
  my @o=$cs->get($t);
  push @d,map { ['domain:contact',$_->srid(),{'type'=>$t}] } @o;
 }
 return @d;
}

sub build_ns
{
 my ($epp,$ns,$domain,$xmlns)=@_;

 $xmlns='domain' unless defined($xmlns);

 my @d;
 my $asattr=$epp->{hostasattr};

 if ($asattr)
 {
  foreach my $i (1..$ns->count())
  {
   my ($n,$r4,$r6)=$ns->get_details($i);
   if (($n=~m/\S+\.${domain}$/i) || (lc($n) eq lc($domain)) || ($asattr==2))
   {
    push @d,map { [$xmlns.':ns',$_,{ip=>'v4'}] } @$r4 if @$r4;
    push @d,map { [$xmlns.':ns',$_,{ip=>'v6'}] } @$r6 if @$r6;
   }
  }
 } else
 {
  @d=map { [$xmlns.':ns',$_] } $ns->get_names();
 }

 return @d;
}


sub renew_parse
{
 my ($po,$otype,$oaction,$oname,$rinfo)=@_;
 my $mes=$po->message();
 return unless $mes->is_success();

 my $rendata=$mes->get_content('renData',$mes->ns('domain'));
 if (!$rendata) {
       $rendata=$mes->get_content('creData',$mes->ns('domain'));
 }
 return unless $rendata;

 my $c=$rendata->getFirstChild();
 while ($c)
 {
  my $name=$c->localname() || $c->nodeName();
  next unless $name;

  if ($name eq 'name')
  {
   $oname=lc($c->getFirstChild()->getData());
   $rinfo->{domain}->{$oname}->{action}='renew';
   $rinfo->{domain}->{$oname}->{exist}=1;
  } elsif ($name=~m/^(exDate)$/)
  {
   $rinfo->{domain}->{$oname}->{$1}=DateTime::Format::ISO8601->new()->parse_datetime($c->getFirstChild()->getData());
  }
  $c=$c->getNextSibling();
 }
}


sub transfer_request
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,['transfer',{'op'=>'request'}],$domain);

 if (verify_rd($rd,'duration'))
 {
  Net::DRI::Util::check_isa($rd->{duration},'DateTime::Duration');
  push @d,build_period($rd->{duration});
 }

 push @d,build_authinfo($rd->{auth}) if (verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 $mes->command_body(\@d);
}

sub transfer_answer
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,['transfer',{'op'=>(verify_rd($rd,'approve') && $rd->{approve})? 'approve' : 'reject'}],$domain);
 push @d,build_authinfo($rd->{auth}) if (verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 $mes->command_body(\@d);
}

sub transfer_cancel
{
 my ($epp,$domain,$rd)=@_;
 my $mes=$epp->message();
 my @d=build_command($mes,['transfer',{'op'=>'cancel'}],$domain);
 push @d,build_authinfo($rd->{auth}) if (verify_rd($rd,'auth') && (ref($rd->{auth}) eq 'HASH'));
 $mes->command_body(\@d);
}

sub update
{
 my ($epp,$domain,$todo)=@_;
 my $mes=$epp->message();

 Net::DRI::Exception::usererr_invalid_parameters($todo." must be a Net::DRI::Data::Changes object") unless ($todo && UNIVERSAL::isa($todo,'Net::DRI::Data::Changes'));

 if ((grep { ! /^(?:add|del)$/ } $todo->types('ns')) ||
     (grep { ! /^(?:add|del)$/ } $todo->types('status')) ||
     (grep { ! /^(?:add|del)$/ } $todo->types('contact')) ||
     (grep { ! /^set$/ } $todo->types('registrant')) ||
     (grep { ! /^set$/ } $todo->types('auth'))
    )
 {
  Net::DRI::Exception->die(0,'protocol/EPP',11,'Only ns/status/contact add/del or registrant/authinfo set available for domain');
 }

 my @d=build_command($mes,'update',$domain);

 my $nsadd=$todo->add('ns');
 my $nsdel=$todo->del('ns');
 my $sadd=$todo->add('status');
 my $sdel=$todo->del('status');
 my $cadd=$todo->add('contact');
 my $cdel=$todo->del('contact');
 my (@add,@del);

 push @add,build_ns($epp,$nsadd,$domain)            if $nsadd && !$nsadd->is_empty();
 push @add,build_contact_noregistrant($cadd)        if $cadd;
 push @add,$sadd->build_xml('domain:status','core') if $sadd;
 push @del,build_ns($epp,$nsdel,$domain)            if $nsdel && !$nsdel->is_empty();
 push @del,build_contact_noregistrant($cdel)        if $cdel;
 push @del,$sdel->build_xml('domain:status','core') if $sdel;

 push @d,['domain:add',@add] if @add;
 push @d,['domain:rem',@del] if @del;

 my $chg=$todo->set('registrant');
 my @chg;
 push @chg,['domain:registrant',$chg->srid()] if ($chg && ref($chg) && UNIVERSAL::can($chg,'srid'));
 $chg=$todo->set('auth');
 push @chg,build_authinfo($chg) if ($chg && ref($chg));
 push @d,['domain:chg',@chg] if @chg;

 ## RFC3731 is ambigous
 ## The text says that domain:add domain:rem or domain:chg must be there,
 ## but the XML schema has minOccurs=0 for each of them
 ## The consensus on the mailing-list is that the XML schema is normative
 ## However some server might follow the text, in which case we will need the following lines
 ## which were removed for Net::DRI 0.16
## my $hasext=(grep { ! /^(?:ns|status|contact|registrant|authinfo)$/ } $todo->types())? 1 : 0;
## push @d,['domain:chg'] if ($hasext && !@chg);
 
 $mes->command_body(\@d);
}

####################################################################################################
1;
