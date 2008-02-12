## Domain Registry Interface, EPP Message
##
## Copyright (c) 2005,2006,2007 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
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

package Net::DRI::Protocol::EPP::Message;

use strict;

use DateTime::Format::ISO8601 ();
use XML::LibXML ();
use Encode ();

use Net::DRI::Protocol::ResultStatus;
use Net::DRI::Exception;
use Net::DRI::Util;

use Carp qw(confess);

use base qw(Class::Accessor::Chained::Fast Net::DRI::Protocol::Message);
__PACKAGE__->mk_accessors(qw(version errcode errmsg errlang command command_body cltrid svtrid ver04login unspec msg_id node_resdata node_extension node_msg result_greeting result_extra_info));

our $VERSION=do { my @r=(q$Revision: 1.18 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

=pod

=head1 NAME

Net::DRI::Protocol::EPP::Message - EPP Message for Net::DRI

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

Copyright (c) 2005,2006,2007 Patrick Mevzek <netdri@dotandco.com>.
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
 my $proto=shift;
 my $class=ref($proto) || $proto;
 my $trid=shift;

 my $self={
           errcode => 2999,
          };

 bless($self,$class);

 $self->cltrid($trid) if (defined($trid) && $trid);
 return $self;
}

sub ns
{
 my ($self,$what)=@_;
 return $self->{ns} unless defined($what);

 if (ref($what) eq 'HASH')
 {
  $self->{ns}=$what;
  return $what;
 }
 return unless exists($self->{ns}->{$what});
 return $self->{ns}->{$what}->[0];
}

sub is_success { return (shift->errcode()=~m/^1/)? 1 : 0; } ## 1XXX is for success, 2XXX for failures

sub result_status
{
 my $self=shift;
 my $rs=Net::DRI::Protocol::ResultStatus->new('epp',$self->errcode(),undef,$self->is_success(),$self->errmsg(),$self->errlang(),$self->result_extra_info());
 $rs->_set_trid([ $self->cltrid(),$self->svtrid() ]);
 return $rs;
}

sub command_extension_register
{
 my ($self,$ocmd,$ons)=@_;

 $self->{extension}=[] unless exists($self->{extension});
 my $eid=1+$#{$self->{extension}};
 $self->{extension}->[$eid]=[$ocmd,$ons,[]];
 return $eid;
}

sub command_extension
{
 my ($self,$eid,$rdata)=@_;

 if (defined($eid) && ($eid >= 0) && ($eid <= $#{$self->{extension}}) && defined($rdata) && (((ref($rdata) eq 'ARRAY') && @$rdata) || ($rdata ne '')))
 {
  $self->{extension}->[$eid]->[2]=(ref($rdata) eq 'ARRAY')? [ @{$self->{extension}->[$eid]->[2]}, @$rdata ] : $rdata;
 } else
 {
  return $self->{extension};
 }
}

sub as_string
{
 my ($self,$to)=@_;
 my $rns=$self->ns();
 my $topns=$rns->{_main};
 my $ens=sprintf('xmlns="%s" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="%s %s"',$topns->[0],$topns->[0],$topns->[1]);
 my @d;
 push @d,'<?xml version="1.0" encoding="UTF-8" standalone="no"?>';
 push @d,'<epp '.$ens.'>';
 my ($cmd,$ocmd,$ons)=@{$self->command()};
 my $nocommand=(!ref($cmd) && (($cmd eq 'hello') || ($cmd eq 'nocommand')));
 push @d,'<command>' unless $nocommand;
 my $attr;
 if (ref($cmd))
 {
  ($cmd,$attr)=($cmd->[0],' '.join(' ',map { $_.'="'.$cmd->[1]->{$_}.'"' } keys(%{$cmd->[1]})));
 } else
 {
  $attr='';
 }

 if ($cmd ne 'nocommand')
 {
  my $body=$self->command_body();
  if (defined($ocmd) && $ocmd)
  {
   push @d,'<'.$cmd.$attr.'>';
   push @d,'<'.$ocmd.' '.$ons.'>';
   push @d,_toxml($body);
   push @d,'</'.$ocmd.'>';
   push @d,'</'.$cmd.'>';
  } else
  {
   if (defined($body) && $body)
   {
    push @d,'<'.$cmd.$attr.'>';
    push @d,_toxml($body);
    push @d,'</'.$cmd.'>';
   } else
   {
    push @d,'<'.$cmd.$attr.'/>';
   }
  }
 }
 
 ## OPTIONAL extension
 my $ext=$self->{extension};
 if (defined($ext) && (ref($ext) eq 'ARRAY') && @$ext)
 {
  push @d,'<extension>';
  foreach my $e (@$ext)
  {
   my ($ecmd,$ens,$rdata)=@$e;
   if ($ecmd && $ens)
   {
    push @d,'<'.$ecmd.' '.$ens.'>';
    push @d,ref($rdata)? _toxml($rdata) : xml_escape($rdata);
    push @d,'</'.$ecmd.'>';
   } else
   {
    push @d,xml_escape(@$rdata);
   }
  }
  push @d,'</extension>';
 }

 ## OPTIONAL unspec (Some registries unfortunately still use this)
 my $unspec = $self->{unspec};
 if (defined($unspec) && ref($unspec) eq 'ARRAY' && @{$unspec})
 {
  push(@d, '<unspec>');
  push @d,xml_escape(@{$unspec});
  push(@d, '</unspec>');
 }

 #### login for version 0.4
 my $ver04login = $self->ver04login();
 my $loginstr = "<login>\n <svcs>\n";
 foreach my $obj (qw(contact host domain svcsub))
 {
 	$loginstr .= '  <' . $obj . ':svc xmlns:' . $obj .
		'="urn:iana:xml:ns:' . $obj . '-1.0" xsi:schemaLocation="' .
		'urn:iana:xml:ns:' . $obj . '-1.0 ' . $obj . "-1.0.xsd\"/>\n";
 }
 $loginstr .= " </svcs>\n</login>\n";
 push(@d, $loginstr) if (defined($ver04login) && $ver04login && !$nocommand);

 ## OPTIONAL clTRID
 my $cltrid=$self->cltrid();
 push @d,'<clTRID>'.$cltrid.'</clTRID>' if (defined($cltrid) && $cltrid && Net::DRI::Util::xml_is_token($cltrid,3,64) && !$nocommand);
 push @d,'</command>' unless $nocommand;
 push @d,'</epp>';

 my $m=Encode::encode('utf8',join('',@d));
 my $l=pack('N',4+length($m)); ## RFC 4934 �4
 return (defined($to) && ($to eq 'tcp') && ($self->version() gt '0.4'))?
	$l.$m : $m;
}

sub _toxml
{
 my $rd=shift;
 my @t;
 foreach my $d ((ref($rd->[0]))? @$rd : ($rd)) ## $d is a node=ref array
 {
  my @c; ## list of children nodes
  my %attr;
  foreach my $e (grep { defined } @$d)
  {
   if (ref($e) eq 'HASH')
   {
    while(my ($k,$v)=each(%$e)) { $attr{$k}=$v; }
   } else
   {
    push @c,$e;
   }
  }
  my $tag=shift(@c);
  my $attr=keys(%attr)? ' '.join(' ',map { $_.'="'.$attr{$_}.'"' } sort(keys(%attr))) : '';
  if (!@c || (@c==1 && !ref($c[0]) && ($c[0] eq '')))
  {
   push @t,"<${tag}${attr}/>";
  } else
  {
   push @t,"<${tag}${attr}>";
   push @t,(@c==1 && !ref($c[0]))? xml_escape($c[0]) : _toxml(\@c);
   push @t,"</${tag}>";
  }
 }
 return @t;
}

sub xml_escape
{
 my $in=shift;
 $in=~s/&/&amp;/g;
 $in=~s/</&lt;/g;
 $in=~s/>/&gt;/g;
 return $in;
}

sub topns { return shift->ns->{_main}->[0]; }

sub get_content
{
 my ($self,$nodename,$ns,$ext)=@_;
 return unless (defined($nodename) && $nodename);

 my @tmp;
 my $n1=$self->node_resdata();
 my $n2=$self->node_extension();

 $ns||=$self->topns();

 if ($ext)
 {
  @tmp=$n2->getElementsByTagNameNS($ns,$nodename) if (defined($n2));
 } else
 {
  @tmp=$n1->getElementsByTagNameNS($ns,$nodename) if (defined($n1));
 }

 return unless @tmp;
 return wantarray()? @tmp : $tmp[0];
}

sub parse
{
 my ($self,$dc,$rinfo)=@_;

 my $NS=$self->topns();
 my $parser=XML::LibXML->new();
 my $xstr = $dc->as_string();
 $xstr =~ s/^\s*//;
 my $doc=$parser->parse_string($xstr);
 my $root=$doc->getDocumentElement();
 my $msg;

 Net::DRI::Exception->die(0,'protocol/EPP',1,'Unsuccessfull parse, root element is not epp') unless ($root->getName() eq 'epp');

 if ($root->getElementsByTagNameNS($NS,'greeting') ||
	$root->getElementsByTagName('greeting'))
 {
  my @el = $root->getElementsByTagNameNS($NS, 'greeting');
  @el = $root->getElementsByTagName('greeting') unless (@el);
  $self->errcode(1000); ## fake an OK
  my $r=$self->parse_greeting($el[0]);
  $self->result_greeting($r);
  return;
 }
 my @rtags = $root->getElementsByTagNameNS($NS, 'response');
 @rtags = $root->getElementsByTagName('response') unless (@rtags);
 Net::DRI::Exception->die(0,'protocol/EPP',1,'Unsuccessfull parse, no response block') unless (@rtags);
 my $res = $rtags[0];

 ## result block(s)
 my @results=$res->getElementsByTagNameNS($NS,'result'); ## one element if success, multiple elements if failure RFC4930 �2.6
 @results = $res->getElementsByTagName('result') unless (@results);
 if (@results)
 {
  my ($errc, $errm, $errl) = $self->parse_result($results[0]);
  my @msgs;

  ## TODO : store all in a stack (to preserve the list of results ?)
  $self->errcode($errc);
  $self->errmsg($errm);
  $self->errlang($errl);

  @msgs = $results[0]->getElementsByTagName('msg');
  $msg = $msgs[0];
 }

 if ($res->getElementsByTagNameNS($NS,'msgQ') || $res->getElementsByTagName('msgQ')) ## OPTIONAL
 {
  my @msgqs = $res->getElementsByTagNameNS($NS,'msgQ');
  @msgqs = $res->getElementsByTagName('msgQ') unless (@msgqs);
  my $msgq = $msgqs[0];
  my $id = $msgq->getAttribute('id'); ##�id of the message that has just been retrieved and dequeued (RFC4930) OR id of *next* available message (RFC3730)
  $id = $msg->getAttribute('id') if (!defined($id) && defined($msg) &&
	defined($msg->getAttribute('id'))); # EPP 0.4
  $rinfo->{message}->{info} = { count => $msgq->getAttribute('count'),
	id => $id };
  if ($msgq->hasChildNodes()) ## We will have childs only as a result of a poll request
  {
   my %d = ( id => $id );
   my $qdtag = ($msgq->getElementsByTagNameNS($NS,'qDate'))[0];
   $qdtag = ($msgq->getElementsByTagName('qDate'))[0] unless (defined($qdtag));
   $self->msg_id($id);
   $d{qdate} = DateTime::Format::ISO8601->new()->parse_datetime(
	$qdtag->firstChild()->getData());
   my $msgc = ($msgq->getElementsByTagNameNS($NS,'msg'))[0];
   $msgc = $msg if (!defined($msgc) && defined($msg));
   $d{lang} = (defined($msgc) && defined($msgc->getAttribute('lang')) ?
	$msgc->getAttribute('lang') : 'en');

   if (grep { $_->nodeType() == 1 && $_->nodeName() ne 'qDate' }
	$msgc->childNodes())
   {
    $self->node_msg($msgc);
   }
   else
   {
    $d{content}=$msgc->firstChild()->getData();
   }
   $rinfo->{message}->{$id}=\%d;
  }
 }

 if ($res->getElementsByTagNameNS($NS,'resData')) ## OPTIONAL
 {
  $self->node_resdata(($res->getElementsByTagNameNS($NS,'resData'))[0]);
 }
 elsif ($res->getElementsByTagName('resData')) ## OPTIONAL
 {
  $self->node_resdata(($res->getElementsByTagName('resData'))[0]);
 }

 if ($res->getElementsByTagNameNS($NS,'extension')) ## OPTIONAL
 {
  $self->node_extension(($res->getElementsByTagNameNS($NS,'extension'))[0]);
 }
 elsif ($res->getElementsByTagName('extension')) ## OPTIONAL
 {
  $self->node_extension(($res->getElementsByTagName('extension'))[0]);
 }

 ## trID
 my $trid=($res->getElementsByTagNameNS($NS,'trID'))[0];
 $trid=($res->getElementsByTagName('trID'))[0] if (!defined($trid));
 my $tmp=extract_trids($trid,$NS,'clTRID');
 $self->cltrid($tmp) if defined($tmp);
 $tmp=extract_trids($trid,$NS,'svTRID');
 $self->svtrid($tmp) if defined($tmp);
}

sub extract_trids
{
 my ($trid,$NS,$what)=@_;
 confess('extract_trids called on empty TRID element') unless (defined($trid));
 my @tmp=$trid->getElementsByTagNameNS($NS,$what);
 return unless @tmp && defined($tmp[0]) && defined($tmp[0]->firstChild());
 return $tmp[0]->firstChild()->getData();
}

sub parse_result
{
 my ($self,$node)=@_;
 my $NS=$self->topns();
 my $code=$node->getAttribute('code');
 my $msg=($node->getElementsByTagNameNS($NS,'msg'))[0];
 $msg = ($node->getElementsByTagName('msg'))[0] unless (defined($msg));
 my $lang=$msg->getAttribute('lang') || 'en';
 $msg=$msg->firstChild()->getData();

 my $c=$node->getFirstChild();
 while ($c)
 {
  next unless ($c->nodeType() == 1); ## only for element nodes
  my $name=$c->nodeName();
  next unless $name;
 
  if ($name eq 'extValue') ## OPTIONAL
  {
   push @{$self->{result_extra_info}},substr(substr($c->toString(),10),0,-11); ## grab everything as a string, without <extValue> and </extValue>
  } elsif ($name eq 'value') ## OPTIONAL
  {
   push @{$self->{result_extra_info}},$c->toString();
  }

 } continue { $c=$c->getNextSibling(); }

 return ($code,$msg,$lang);
}

sub parse_greeting
{
 my ($self,$g)=@_;
 my %tmp;
 my $c=$g->getFirstChild();
 while($c)
 {
  next unless ($c->nodeType() == 1); ## only for element nodes
  my $n=$c->getName();
  if ($n=~m/^(svID|svDate)$/)
  {
   $tmp{$1}=$c->getFirstChild->getData();
  } elsif ($n eq 'svcMenu')
  {
   my $cc=$c->getFirstChild();
   while($cc)
   {
    next unless ($cc->nodeType() == 1); ## only for element nodes
    my $nn=$cc->getName();
    if ($nn=~m/^(version|lang)$/)
    {
     push @{$tmp{$1}},$cc->getFirstChild->getData();
    } elsif ($nn eq 'objURI')
    {
     push @{$tmp{svcs}},$cc->getFirstChild->getData();
    } elsif ($nn eq 'svcExtension')
    {
     push @{$tmp{svcext}},map { $_->getFirstChild->getData() } grep { $_->getName() eq 'extURI' } $cc->getChildNodes();
    }
   } continue { $cc=$cc->getNextSibling(); }
  } elsif ($n eq 'dcp')
  {
   ## TODO : do something with that data
  }
 } continue { $c=$c->getNextSibling(); }

 return \%tmp;
}

####################################################################################################

sub get_name_from_message
{
 my ($self)=@_;
 my $cb=$self->command_body();
 return 'session' unless (defined($cb) && ref($cb)); ## TO FIX
 foreach my $e (@$cb)
 {
  return $e->[1] if ($e->[0]=~m/^(?:domain|host|nsgroup):name$/); ## TO FIX (notably in case of check_multi)
  return $e->[1] if ($e->[0]=~m/^(?:contact|defreg):id$/); ## TO FIX
 }
 return 'session'; ## TO FIX
}

####################################################################################################
1;
