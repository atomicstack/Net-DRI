#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;

use Test::More tests => 5;

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2='</epp>';
our $TRID='<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

our $R1;
sub mysend
{
 my ($transport,$count,$msg)=@_;
 $R1=$msg->as_string();
 return 1;
}

our $R2;
sub myrecv
{
 return Net::DRI::Data::Raw->new_from_string($R2? $R2 : $E1.'<response>'.r().$TRID.'</response>'.$E2);
}

my $dri=Net::DRI->new(10);
$dri->add_registry('VNDS');
$dri->target('VNDS')->new_current_profile('p1','Net::DRI::Transport::Dummy',[{f_send=>\&mysend,f_recv=>\&myrecv}],'Net::DRI::Protocol::EPP::Extensions::US',[]);

#########################################################################################################
## Examples taken from draft-liu-epp-usTLD-00 + updates to current EPP

my $c=$dri->local_object('contact');
$c->srid('abcde')->name('abc')->org('abc.org')->street(['123 d street'])->city('reston')->pc(20194)->sp('VA')->cc('US')->fax('+1.2345678901x1234')->email('xxx@yyy.com');
$c->auth({pw => 123456});

$c->application_purpose('P1');
$c->nexus_category('C31/DE');

$dri->{registries}->{VNDS}->{trid}=sub { return 'coricopat-9978-1002'; };
my $rc=$dri->contact_create($c);
is($R1,$E1.'<command><create><contact:create xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>abcde</contact:id><contact:postalInfo type="loc"><contact:name>abc</contact:name><contact:org>abc.org</contact:org><contact:addr><contact:street>123 d street</contact:street><contact:city>reston</contact:city><contact:sp>VA</contact:sp><contact:pc>20194</contact:pc><contact:cc>US</contact:cc></contact:addr></contact:postalInfo><contact:fax x="1234">+1.2345678901</contact:fax><contact:email>xxx@yyy.com</contact:email><contact:authInfo><contact:pw>123456</contact:pw></contact:authInfo></contact:create></create><extension>AppPurpose=P1 NexusCategory=C31/DE</extension><clTRID>coricopat-9978-1002</clTRID></command>'.$E2,'contact_create with nexus info build');

$R2=$E1.'<response>'.r().'<resData><contact:infData xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>abcde</contact:id><contact:roid>ABCDE-US</contact:roid><contact:status s="linked"/><contact:status s="clientDeleteProhibited"/><contact:postalInfo type="loc"><contact:name>abc</contact:name><contact:org>abc.org</contact:org><contact:addr><contact:street>123 d street</contact:street><contact:city>reston</contact:city><contact:sp>VA</contact:sp><contact:pc>20194</contact:pc><contact:cc>US</contact:cc></contact:addr></contact:postalInfo><contact:fax x="1234">+1.2345678901</contact:fax><contact:email>xxx@yyy.com</contact:email><contact:clID>ClientY</contact:clID><contact:crID>ClientX</contact:crID><contact:crDate>2002-04-03T22:00:00.0Z</contact:crDate><contact:upID>ClientX</contact:upID><contact:upDate>2002-12-03T09:00:00.0Z</contact:upDate><contact:trDate>2000-04-08T09:00:00.0Z</contact:trDate><contact:authInfo><contact:pw>123456</contact:pw></contact:authInfo></contact:infData></resData><extension>AppPurpose=P1 NexusCategory=C11</extension><trID><clTRID>coricopat-9978-1003</clTRID><svTRID>54322-XYZ</svTRID></trID></response>'.$E2;
$co=$dri->local_object('contact')->srid('abcde')->auth({pw=>'123456'});
$rc=$dri->contact_info($co);
$c=$dri->get_info('self','contact','abcde');
is($c->application_purpose(),'P1','contact_info parse AppPurpose');
is($c->nexus_category(),'C11','contact_info parse NexusCategory');

$R2='';
my $co=$dri->local_object('contact')->srid('abc');
my $toc=$dri->local_object('changes');
my $co2=$dri->local_object('contact');
$co2->voice('+1.2345678910');
$co2->application_purpose('P3');
$co2->nexus_category('C11');
$toc->set('info',$co2);
$rc=$dri->contact_update($co,$toc);
is($R1,$E1.'<command><update><contact:update xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>abc</contact:id><contact:chg><contact:voice>+1.2345678910</contact:voice></contact:chg></contact:update></update><extension>AppPurpose=P3 NexusCategory=C11</extension><clTRID>coricopat-9978-1002</clTRID></command>'.$E2,'contact_update build 1');

$co2=$dri->local_object('contact');
$co2->application_purpose('');
$toc->set('info',$co2);
$rc=$dri->contact_update($co,$toc);
is($R1,$E1.'<command><update><contact:update xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>abc</contact:id></contact:update></update><extension>AppPurpose=</extension><clTRID>coricopat-9978-1002</clTRID></command>'.$E2,'contact_update build 2');


exit 0;

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}