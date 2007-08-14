#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;

use Test::More tests => 59;

eval { use Test::LongString max => 100; $Test::LongString::Context=50; };
*{'main::is_string'}=\&main::is if $@;

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
$dri->{trid_factory}=sub { return 'ABC-12345'; };
$dri->add_registry('LU');
$dri->target('LU')->new_current_profile('p1','Net::DRI::Transport::Dummy',[{f_send=>\&mysend,f_recv=>\&myrecv}],'Net::DRI::Protocol::EPP::Extensions::LU',[]);

my $rc;
my $s;
my $d;
my ($dh,@c);

####################################################################################################
## Registry Messages

$R2=$E1.'<response>'.r(1301,'Command completed successfully; ack to dequeue').'<msgQ count="4" id="1"><qDate>2005-10-03T07:55:13Z</qDate><msg lang="en"><dnslu:pollmsg type="1234" xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:roid>D123-DNSLU</dnslu:roid><dnslu:object>mydomain.lu</dnslu:object><dnslu:clTRID>89ABCDEF</dnslu:clTRID><dnslu:svTRID>13868389</dnslu:svTRID><dnslu:exDate>2005-10-05T07:37:10Z</dnslu:exDate><dnslu:ns name="ns.domain.lu">Test failed</dnslu:ns><dnslu:reason>Because!</dnslu:reason><dnslu:extra name="field">some extra information</dnslu:extra></dnslu:pollmsg></msg></msgQ><trID ><clTRID>ABC-12345</clTRID><svTRID>4516E89-DNSLU</svTRID></trID></response></epp>';
$rc=$dri->message_retrieve();
is($dri->get_info('last_id'),1,'message get_info last_id 1');
is($dri->get_info('last_id','message','session'),1,'message get_info last_id 2');
is($dri->get_info('id','message',1),1,'message get_info id');
is(''.$dri->get_info('qdate','message',1),'2005-10-03T07:55:13','message get_info qdate');
is($dri->get_info('lang','message',1),'en','message get_info lang');
is($dri->get_info('roid','message',1),'D123-DNSLU','message get_info roid');
is($dri->get_info('object','message',1),'mydomain.lu','message get_info object');
is($dri->get_info('clTRID','message',1),'89ABCDEF','message get_info clTRID');
is($dri->get_info('svTRID','message',1),'13868389','message get_info svTRID');
is(''.$dri->get_info('exDate','message',1),'2005-10-05T07:37:10','message get_info exDate');
is_deeply($dri->get_info('ns','message',1),{'ns.domain.lu'=>'Test failed'},'message get_info ns');
is($dri->get_info('reason','message',1),'Because!','message get_info reason');
is_deeply($dri->get_info('extra','message',1),{'field'=>'some extra information'},'message get_info extra');

###################################################################################################
## Contact commands

$R2=$E1.'<response>'.r().'<resData><contact:infData xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>H0008</contact:id><contact:roid>H3-DNSLU</contact:roid><contact:status s="ok"/><contact:status s="linked"/><contact:postalInfo type="loc"><contact:name>Fondation RESTENA</contact:name><contact:addr><contact:street>6, rue Coudenhove -Kalergi</contact:street><contact:city>Luxembourg</contact:city><contact:pc>1359</contact:pc><contact:cc>LU</contact:cc></contact:addr></contact:postalInfo><contact:email>dummy@dns.lu</contact:email><contact:clID>restena-id</contact:clID><contact:crID>restena-id</contact:crID><contact:crDate>2005-10-05T07:37:10Z</contact:crDate><contact:upID>restena-id</contact:upID><contact:upDate>2005-11-17T12:59:11Z</contact:upDate></contact:infData></resData><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xmlns:xsi="http://www.w3.org/200/10/XMLSchema-instance" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0.xsd"><dnslu:resData><dnslu:infData><dnslu:contact><dnslu:type>holder_org</dnslu:type><dnslu:disclose><dnslu:name flag="1"/><dnslu:addr flag="0"/></dnslu:disclose></dnslu:contact></dnslu:infData></dnslu:resData></dnslu:ext></extension>'.$TRID.'</response>'.$E2; 

$co=$dri->local_object('contact')->srid('H0008');
$rc=$dri->contact_info($co);
is($rc->is_success(),1,'contact_info is_success');
is($dri->get_info('action'),'info','contact_info get_info(action)');
is($dri->get_info('exist'),1,'contact_info get_info(exist)');
$co=$dri->get_info('self');
isa_ok($co,'Net::DRI::Data::Contact','contact_info get_info(self)');
is($co->type(),'holder_org','contact->type()');
is_deeply($co->disclose(),{name_loc=>1,addr_loc=>0},'contact->disclose()');

$R2=$E1.'<response>'.r().'<resData><contact:creData xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>th1domainTest</contact:id><contact:crDate>1999-04-03T22:00:00.0Z</contact:crDate></contact:creData></resData>'.$TRID.'</response>'.$E2;
$co=$dri->local_object('contact')->srid('H100');
$co->name('Fondation RESTENA');
$co->street(['6, rue Coudenhove -Kalergi']);
$co->city('Luxembourg');
$co->pc(1359);
$co->cc('LU');
$co->email('dummy@dnslu.lu');
$co->auth({pw=>'dummy'});
$co->type('holder_org');
$co->disclose({name_loc=>1,addr_loc=>0});
$rc=$dri->contact_create($co);
is_string($R1,$E1.'<command><create><contact:create xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>H100</contact:id><contact:postalInfo type="loc"><contact:name>Fondation RESTENA</contact:name><contact:addr><contact:street>6, rue Coudenhove -Kalergi</contact:street><contact:city>Luxembourg</contact:city><contact:pc>1359</contact:pc><contact:cc>LU</contact:cc></contact:addr></contact:postalInfo><contact:email>dummy@dnslu.lu</contact:email><contact:authInfo><contact:pw>dummy</contact:pw></contact:authInfo></contact:create></create><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:create><dnslu:contact><dnslu:type>holder_org</dnslu:type><dnslu:disclose><dnslu:name flag="1"/><dnslu:addr flag="0"/></dnslu:disclose></dnslu:contact></dnslu:create></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'contact_create build 1');

$R2=$E1.'<response>'.r().'<resData><contact:creData xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>th1domainTest</contact:id><contact:crDate>1999-04-03T22:00:00.0Z</contact:crDate></contact:creData></resData>'.$TRID.'</response>'.$E2;
$co=$dri->local_object('contact')->srid('C100');
$co->name('Bruno Pr�mont');
$co->org('Fondation RESTENA');
$co->street(['6, rue Coudenhove -Kalergi']);
$co->city('Luxembourg');
$co->pc(1359);
$co->cc('LU');
$co->voice('+352.42440928');
$co->fax('+352.42440928');
$co->email('bruno.premont@restena.lu');
$co->auth({pw=>'dummy'});
$co->type('contact');
$co->disclose({name_loc=>1,addr_loc=>0,voice=>0,email=>0});
$rc=$dri->contact_create($co);
is_string($R1,$E1.'<command><create><contact:create xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>C100</contact:id><contact:postalInfo type="loc"><contact:name>Bruno Prémont</contact:name><contact:org>Fondation RESTENA</contact:org><contact:addr><contact:street>6, rue Coudenhove -Kalergi</contact:street><contact:city>Luxembourg</contact:city><contact:pc>1359</contact:pc><contact:cc>LU</contact:cc></contact:addr></contact:postalInfo><contact:voice>+352.42440928</contact:voice><contact:fax>+352.42440928</contact:fax><contact:email>bruno.premont@restena.lu</contact:email><contact:authInfo><contact:pw>dummy</contact:pw></contact:authInfo></contact:create></create><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:create><dnslu:contact><dnslu:type>contact</dnslu:type><dnslu:disclose><dnslu:name flag="1"/><dnslu:addr flag="0"/><dnslu:voice flag="0"/><dnslu:email flag="0"/></dnslu:disclose></dnslu:contact></dnslu:create></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'contact_create build 2'); 

$R2='';
$co=$dri->local_object('contact')->srid('H100');
$toc=$dri->local_object('changes');
my $co2=$dri->local_object('contact');
$co2->name('Gilles Massen');
$co2->street(['Building A','Department X','rue de Luxembourg 10']);
$co2->city('Luxembourg');
$co2->pc('1359');
$co2->cc('LU');
$toc->set('info',$co2);
$toc->add('disclose',{name_loc=>0,addr_loc=>1});
$toc->del('disclose',{name_loc=>1,addr_loc=>1});
$rc=$dri->contact_update($co,$toc);
is_string($R1,$E1.'<command><update><contact:update xmlns:contact="urn:ietf:params:xml:ns:contact-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:contact-1.0 contact-1.0.xsd"><contact:id>H100</contact:id><contact:chg><contact:postalInfo type="loc"><contact:name>Gilles Massen</contact:name><contact:addr><contact:street>Building A</contact:street><contact:street>Department X</contact:street><contact:street>rue de Luxembourg 10</contact:street><contact:city>Luxembourg</contact:city><contact:pc>1359</contact:pc><contact:cc>LU</contact:cc></contact:addr></contact:postalInfo></contact:chg></contact:update></update><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:update><dnslu:contact><dnslu:add><dnslu:disclose><dnslu:name flag="0"/><dnslu:addr flag="1"/></dnslu:disclose></dnslu:add><dnslu:rem><dnslu:disclose><dnslu:name flag="1"/><dnslu:addr flag="1"/></dnslu:disclose></dnslu:rem></dnslu:contact></dnslu:update></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'contact_update build 1');

#####################################################################################
## Domain commands

$R2=$E1.'<response>'.r().'<resData><domain:infData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>lycee.lu</domain:name><domain:roid>D0-DNSLU</domain:roid><domain:status s="pendingCreate"/><domain:status s="inactive"/><domain:registrant>H100</domain:registrant><domain:contact type="admin">C100</domain:contact><domain:contact type="tech">C100</domain:contact><domain:ns><domain:hostObj>ns.restena.lu</domain:hostObj></domain:ns><domain:host>ns1.xn--lyce-dpa.lu</domain:host><domain:host>ns6.xn--lyce-dpa.lu</domain:host><domain:clID>restena-id</domain:clID><domain:crID>restena-id</domain:crID><domain:crDate>2005-10-03T17:22:31Z</domain:crDate><domain:upID>restena-id</domain:upID><domain:upDate>2006-06-27T11:10:46Z</domain:upDate><domain:exDate>2006-10-03T17:22:31Z</domain:exDate></domain:infData></resData><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0.xsd"><dnslu:resData><dnslu:infData><dnslu:domain><dnslu:idn>lycée.lu</dnslu:idn><dnslu:status>serverTradeProhibited</dnslu:status><dnslu:crReqID>restena-id</dnslu:crReqID><dnslu:crReqDate>2005-10-03T11:37:22Z</dnslu:crReqDate><dnslu:delReqDate>2006-07-03T11:12:12Z</dnslu:delReqDate><dnslu:delDate>2006-07-21T17:37:54Z</dnslu:delDate></dnslu:domain></dnslu:infData></dnslu:resData></dnslu:ext></extension>'.$TRID.'</response>'.$E2;
$rc=$dri->domain_info('lycee.lu');
is_deeply([$dri->get_info('status')->list_status()],['inactive','pendingCreate','serverTradeProhibited'],'domain_info get_info(status)');
is($dri->get_info('crReqID'),'restena-id','domain_info get_info(crReqID)');
is(''.$dri->get_info('crReqDate'),'2005-10-03T11:37:22','domain_info get_info(crReqDate)');
is(''.$dri->get_info('delReqDate'),'2006-07-03T11:12:12','domain_info get_info(delReqDate)');
is(''.$dri->get_info('delDate'),'2006-07-21T17:37:54','domain_info get_info(delDate)');


## (we do not handle idn for now)
$R2='';
my $cs=$dri->local_object('contactset');
$cs->set($dri->local_object('contact')->srid('H_rest'),'registrant');
$cs->set($dri->local_object('contact')->srid('CA_rest'),'admin');
$cs->set($dri->local_object('contact')->srid('CT_rest'),'tech');
$rc=$dri->domain_create_only('lycee.lu',{ns=>$dri->local_object('hosts')->set(['ns1.restena.lu'],['ns2.restena.lu']),contact=>$cs,auth=>{pw=>'dummy'},status=>$dri->local_object('status')->add('inactive','clientTradeProhibited')});
is_string($R1,$E1.'<command><create><domain:create xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>lycee.lu</domain:name><domain:ns><domain:hostObj>ns1.restena.lu</domain:hostObj><domain:hostObj>ns2.restena.lu</domain:hostObj></domain:ns><domain:registrant>H_rest</domain:registrant><domain:contact type="admin">CA_rest</domain:contact><domain:contact type="tech">CT_rest</domain:contact><domain:authInfo><domain:pw>dummy</domain:pw></domain:authInfo></domain:create></create><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:create><dnslu:domain><dnslu:status s="clientTradeProhibited"/><dnslu:status s="inactive"/></dnslu:domain></dnslu:create></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_create_only build'); 


$R2='';
my $toc=$dri->local_object('changes');
$cs=$dri->local_object('contactset');
$cs->set($dri->local_object('contact')->srid('C100'),'admin');
$cs->set($dri->local_object('contact')->srid('C100'),'tech');
$toc->add('contact',$cs);
$toc->del('contact',$cs);
$toc->add('ns',$dri->local_object('hosts')->set(['ns1.restena.lu'],['ns2.restena.lu'],['ns3.restena.lu']));
$toc->add('status',$dri->local_object('status')->add('clientUpdateProhibited','clientTradeProhibited'));
$toc->del('ns',$dri->local_object('hosts')->set(['ns1.restena.lu'],['ns2.restena.lu'],['ns3.restena.lu']));
$toc->del('status',$dri->local_object('status')->add('clientDeleteProhibited','clientTransferProhibited2')); ## last status changed because otherwise in core
$rc=$dri->domain_update('lycee.lu',$toc);
is_string($R1,$E1.'<command><update><domain:update xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>lycee.lu</domain:name><domain:add><domain:ns><domain:hostObj>ns1.restena.lu</domain:hostObj><domain:hostObj>ns2.restena.lu</domain:hostObj><domain:hostObj>ns3.restena.lu</domain:hostObj></domain:ns><domain:contact type="admin">C100</domain:contact><domain:contact type="tech">C100</domain:contact><domain:status s="clientUpdateProhibited"/></domain:add><domain:rem><domain:ns><domain:hostObj>ns1.restena.lu</domain:hostObj><domain:hostObj>ns2.restena.lu</domain:hostObj><domain:hostObj>ns3.restena.lu</domain:hostObj></domain:ns><domain:contact type="admin">C100</domain:contact><domain:contact type="tech">C100</domain:contact><domain:status s="clientDeleteProhibited"/></domain:rem></domain:update></update><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:update><dnslu:domain><dnslu:add><dnslu:status s="clientTradeProhibited"/></dnslu:add><dnslu:rem><dnslu:status s="clientTransferProhibited2"/></dnslu:rem></dnslu:domain></dnslu:update></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_update build');

$R2='';
$rc=$dri->domain_delete('domain.lu',{delDate=>'immediate'});
is_string($R1,$E1.'<command><delete><domain:delete xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>domain.lu</domain:name></domain:delete></delete><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:delete><dnslu:domain><dnslu:op>immediate</dnslu:op></dnslu:domain></dnslu:delete></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_delete immediate');

$R2='';
$rc=$dri->domain_delete('domain.lu',{delDate=>DateTime->new(year=>2005,month=>11,day=>8)});
is_string($R1,$E1.'<command><delete><domain:delete xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>domain.lu</domain:name></domain:delete></delete><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:delete><dnslu:domain><dnslu:op>setDate</dnslu:op><dnslu:delDate>2005-11-08T00:00:00Z</dnslu:delDate></dnslu:domain></dnslu:delete></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_delete setDate');

$R2='';
$rc=$dri->domain_delete('domain.lu',{delDate=>'cancel'});
is_string($R1,$E1.'<command><delete><domain:delete xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>domain.lu</domain:name></domain:delete></delete><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:delete><dnslu:domain><dnslu:op>cancel</dnslu:op></dnslu:domain></dnslu:delete></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_delete cancel');

## clTRID seems wrong in example
$R2='';
my $ro=$dri->remote_object('domain');
$rc=$ro->restore('domain.lu');
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:restore><dnslu:domain><dnslu:name>domain.lu</dnslu:name></dnslu:domain></dnslu:restore></dnslu:command></dnslu:ext></extension>'.$E2,'domain_restore');

## example seems wrong: wrong namespace (dnslu instead of domain) in non extension aprt
$R2=$E1.'<response>'.r(1001,'Command completed successfully ; action pending').'<resData><domain:trnData xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>cafe.lu</domain:name><domain:trStatus>pending</domain:trStatus><domain:reID>restena-id</domain:reID><domain:reDate>2004-09-08T11:39:41Z</domain:reDate><domain:acDate>2004-09-15T11:39:41Z</domain:acDate></domain:trnData></resData><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation ="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:resData><dnslu:trnData><dnslu:domain><dnslu:trDate>2004-09-18T10:00:00Z</dnslu:trDate></dnslu:domain></dnslu:trnData></dnslu:resData></dnslu:ext></extension>'.$TRID.'</response>'.$E2;
$cs=$dri->local_object('contactset');
$cs->set($dri->local_object('contact')->srid('H100'),'registrant');
$cs->set($dri->local_object('contact')->srid('C100'),'admin');
$cs->set($dri->local_object('contact')->srid('C100'),'tech');
$rc=$ro->transfer_request('cafe.lu',{ns=>$dri->local_object('hosts')->set(['ns1.restena.lu'],['ns2.restena.lu'],['ns3.restena.lu']),contact=>$cs,status=>$dri->local_object('status')->no('publish'),trDate=>DateTime->new(year=>2004,month=>6,day=>30)});
is_string($R1,$E1.'<command><transfer op="request"><domain:transfer xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>cafe.lu</domain:name></domain:transfer></transfer><extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:transfer><dnslu:domain><dnslu:ns><dnslu:hostObj>ns1.restena.lu</dnslu:hostObj><dnslu:hostObj>ns2.restena.lu</dnslu:hostObj><dnslu:hostObj>ns3.restena.lu</dnslu:hostObj></dnslu:ns><dnslu:registrant>H100</dnslu:registrant><dnslu:contact type="admin">C100</dnslu:contact><dnslu:contact type="tech">C100</dnslu:contact><dnslu:status s="clientHold"/><dnslu:trDate>2004-06-30</dnslu:trDate></dnslu:domain></dnslu:transfer></dnslu:ext></extension><clTRID>ABC-12345</clTRID></command>'.$E2,'domain_transfer_request build'); 
is(''.$dri->get_info('trDate'),'2004-09-18T10:00:00','domain_transfer_request get_info(trDate)');

$R2='';
$cs=$dri->local_object('contactset');
$cs->set($dri->local_object('contact')->srid('H100'),'registrant');
$cs->set($dri->local_object('contact')->srid('C100'),'admin');
$cs->set($dri->local_object('contact')->srid('C100'),'tech');
$rc=$ro->trade_request('cafe.lu',{ns=>$dri->local_object('hosts')->set(['ns1.restena.lu'],['ns2.restena.lu'],['ns3.restena.lu']),contact=>$cs,status=>$dri->local_object('status')->no('publish'),trDate=>DateTime->new(year=>2004,month=>6,day=>30)});
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:trade op="request"><dnslu:domain><dnslu:name>cafe.lu</dnslu:name><dnslu:ns><dnslu:hostObj>ns1.restena.lu</dnslu:hostObj><dnslu:hostObj>ns2.restena.lu</dnslu:hostObj><dnslu:hostObj>ns3.restena.lu</dnslu:hostObj></dnslu:ns><dnslu:registrant>H100</dnslu:registrant><dnslu:contact type="admin">C100</dnslu:contact><dnslu:contact type="tech">C100</dnslu:contact><dnslu:status s="clientHold"/><dnslu:trDate>2004-06-30</dnslu:trDate></dnslu:domain></dnslu:trade></dnslu:command></dnslu:ext></extension>'.$E2,'domain_trade_request build');

$R2=$E1.'<response>'.r().'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation ="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:resData><dnslu:traData><dnslu:domain><dnslu:name>cafe.lu</dnslu:name><dnslu:trStatus>pending</dnslu:trStatus><dnslu:reID>restena-id</dnslu:reID><dnslu:reDate>2004-09-08T11:39:41Z</dnslu:reDate><dnslu:acDate>2004-09-15T11:39:41Z</dnslu:acDate><dnslu:trDate>2004-09-18T10:00:00Z</dnslu:trDate></dnslu:domain></dnslu:traData></dnslu:resData></dnslu:ext></extension>'.$TRID.'</response>'.$E2;
$rc=$ro->trade_query('cafe.lu');
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:trade op="query"><dnslu:domain><dnslu:name>cafe.lu</dnslu:name></dnslu:domain></dnslu:trade></dnslu:command></dnslu:ext></extension>'.$E2,'domain_trade_query build');
is($dri->get_info('trStatus'),'pending','domain_trade_query get_info(trStatus)');
is($dri->get_info('reID'),'restena-id','domain_trade_query get_info(reID)');
is(''.$dri->get_info('reDate'),'2004-09-08T11:39:41','domain_trade_query get_info(reDate)');
is(''.$dri->get_info('acDate'),'2004-09-15T11:39:41','domain_trade_query get_info(acDate)');
is(''.$dri->get_info('trDate'),'2004-09-18T10:00:00','domain_trade_query get_info(trDate)');


$R2='';
$rc=$ro->trade_cancel('domain.lu');
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:trade op="cancel"><dnslu:domain><dnslu:name>domain.lu</dnslu:name></dnslu:domain></dnslu:trade></dnslu:command></dnslu:ext></extension>'.$E2,'domain_trade_cancel build');


$R2='';
$cs=$dri->local_object('contactset');
$cs->set($dri->local_object('contact')->srid('H100'),'registrant');
$cs->set($dri->local_object('contact')->srid('C100'),'admin');
$cs->set($dri->local_object('contact')->srid('C100'),'tech');
$rc=$ro->transfer_trade_request('cafe.lu',{ns=>$dri->local_object('hosts')->set(['ns1.restena.lu'],['ns2.restena.lu'],['ns3.restena.lu']),contact=>$cs,status=>$dri->local_object('status')->no('publish'),trDate=>DateTime->new(year=>2004,month=>6,day=>30)});
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:transferTrade op="request"><dnslu:domain><dnslu:name>cafe.lu</dnslu:name><dnslu:ns><dnslu:hostObj>ns1.restena.lu</dnslu:hostObj><dnslu:hostObj>ns2.restena.lu</dnslu:hostObj><dnslu:hostObj>ns3.restena.lu</dnslu:hostObj></dnslu:ns><dnslu:registrant>H100</dnslu:registrant><dnslu:contact type="admin">C100</dnslu:contact><dnslu:contact type="tech">C100</dnslu:contact><dnslu:status s="clientHold"/><dnslu:trDate>2004-06-30</dnslu:trDate></dnslu:domain></dnslu:transferTrade></dnslu:command></dnslu:ext></extension>'.$E2,'domain_transfer_trade_request build');

$R2=$E1.'<response>'.r().'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation ="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:resData><dnslu:trnTraData><dnslu:domain><dnslu:name>cafe.lu</dnslu:name><dnslu:trStatus>pending</dnslu:trStatus><dnslu:reID>restena-id</dnslu:reID><dnslu:reDate>2004-09-08T11:39:41Z</dnslu:reDate><dnslu:acDate>2004-09-15T11:39:41Z</dnslu:acDate><dnslu:trDate>2004-09-18T10:00:00Z</dnslu:trDate></dnslu:domain></dnslu:trnTraData></dnslu:resData></dnslu:ext></extension>'.$TRID.'</response>'.$E2;
$rc=$ro->transfer_trade_query('cafe.lu');
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:transferTrade op="query"><dnslu:domain><dnslu:name>cafe.lu</dnslu:name></dnslu:domain></dnslu:transferTrade></dnslu:command></dnslu:ext></extension>'.$E2,'domain_transfer_trade_query build');
is($dri->get_info('trStatus'),'pending','domain_transfer_trade_query get_info(trStatus)');
is($dri->get_info('reID'),'restena-id','domain_transfer_trade_query get_info(reID)');
is(''.$dri->get_info('reDate'),'2004-09-08T11:39:41','domain_transfer_trade_query get_info(reDate)');
is(''.$dri->get_info('acDate'),'2004-09-15T11:39:41','domain_transfer_trade_query get_info(acDate)');
is(''.$dri->get_info('trDate'),'2004-09-18T10:00:00','domain_transfer_trade_query get_info(trDate)');

$R2='';
$rc=$ro->transfer_trade_cancel('domain.lu');
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:transferTrade op="cancel"><dnslu:domain><dnslu:name>domain.lu</dnslu:name></dnslu:domain></dnslu:transferTrade></dnslu:command></dnslu:ext></extension>'.$E2,'domain_transfer_trade_cancel build');


$R2='';
$cs=$dri->local_object('contactset');
$cs->set($dri->local_object('contact')->srid('H100'),'registrant');
$cs->set($dri->local_object('contact')->srid('C100'),'admin');
$cs->set($dri->local_object('contact')->srid('C100'),'tech');
$rc=$ro->transfer_restore_request('cafe.lu',{ns=>$dri->local_object('hosts')->set(['ns1.restena.lu'],['ns2.restena.lu'],['ns3.restena.lu']),contact=>$cs,status=>$dri->local_object('status')->no('publish'),trDate=>DateTime->new(year=>2004,month=>6,day=>30)});
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:transferRestore op="request"><dnslu:domain><dnslu:name>cafe.lu</dnslu:name><dnslu:ns><dnslu:hostObj>ns1.restena.lu</dnslu:hostObj><dnslu:hostObj>ns2.restena.lu</dnslu:hostObj><dnslu:hostObj>ns3.restena.lu</dnslu:hostObj></dnslu:ns><dnslu:registrant>H100</dnslu:registrant><dnslu:contact type="admin">C100</dnslu:contact><dnslu:contact type="tech">C100</dnslu:contact><dnslu:status s="clientHold"/><dnslu:trDate>2004-06-30</dnslu:trDate></dnslu:domain></dnslu:transferRestore></dnslu:command></dnslu:ext></extension>'.$E2,'domain_transfer_restore_request build');

$R2=$E1.'<response>'.r().'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation ="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:resData><dnslu:trnResData><dnslu:domain><dnslu:name>cafe.lu</dnslu:name><dnslu:trStatus>pending</dnslu:trStatus><dnslu:reID>restena-id</dnslu:reID><dnslu:reDate>2004-09-08T11:39:41Z</dnslu:reDate><dnslu:acDate>2004-09-15T11:39:41Z</dnslu:acDate><dnslu:trDate>2004-09-18T10:00:00Z</dnslu:trDate></dnslu:domain></dnslu:trnResData></dnslu:resData></dnslu:ext></extension>'.$TRID.'</response>'.$E2;
$rc=$ro->transfer_restore_query('cafe.lu');
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:transferRestore op="query"><dnslu:domain><dnslu:name>cafe.lu</dnslu:name></dnslu:domain></dnslu:transferRestore></dnslu:command></dnslu:ext></extension>'.$E2,'domain_transfer_restore_query build');
is($dri->get_info('trStatus'),'pending','domain_transfer_restore_query get_info(trStatus)');
is($dri->get_info('reID'),'restena-id','domain_transfer_restore_query get_info(reID)');
is(''.$dri->get_info('reDate'),'2004-09-08T11:39:41','domain_transfer_restore_query get_info(reDate)');
is(''.$dri->get_info('acDate'),'2004-09-15T11:39:41','domain_transfer_restore_query get_info(acDate)');
is(''.$dri->get_info('trDate'),'2004-09-18T10:00:00','domain_transfer_restore_query get_info(trDate)');

$R2='';
$rc=$ro->transfer_restore_cancel('domain.lu');
is_string($R1,$E1.'<extension><dnslu:ext xmlns:dnslu="http://www.dns.lu/xml/epp/dnslu-1.0" xsi:schemaLocation="http://www.dns.lu/xml/epp/dnslu-1.0 dnslu-1.0.xsd"><dnslu:command><dnslu:transferRestore op="cancel"><dnslu:domain><dnslu:name>domain.lu</dnslu:name></dnslu:domain></dnslu:transferRestore></dnslu:command></dnslu:ext></extension>'.$E2,'domain_transfer_restore_cancel build');

exit 0;

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}