#!/usr/bin/perl -w

use Net::DRI;
use Net::DRI::Data::Raw;
use DateTime::Duration;
use Data::Dumper;

use Test::More tests => 10;

eval { use Test::LongString max => 100; $Test::LongString::Context = 50; };
*{'main::is_string'} = \&main::is if $@;

our $E1='<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd">';
our $E2='</epp>';
our $TRID='<trID><clTRID>ABC-12345</clTRID><svTRID>54322-XYZ</svTRID></trID>';

our $R1;
sub mysend
{
	my ($transport, $count, $msg) = @_;
	$R1 = $msg->as_string();
	return 1;
}

our $R2;
sub myrecv
{
	return Net::DRI::Data::Raw->new_from_string($R2 ? $R2 : $E1 .
		'<response>' . r() . $TRID . '</response>' . $E2);
}

my $dri;
eval {
	$dri = Net::DRI->new(10);
};
print $@->as_string() if $@;
$dri->{trid_factory} = sub { return 'ABC-12345'; };
$dri->add_registry('TRAVEL');
eval {
	$dri->target('TRAVEL')->new_current_profile('p1',
		'Net::DRI::Transport::Dummy',
		[{
			f_send=> \&mysend,
			f_recv=> \&myrecv
		}], 'Net::DRI::Protocol::EPP',
		['1.0',['Net::DRI::Protocol::EPP::Extensions::NeuLevel::UIN']]);
};
print $@->as_string() if $@;


my $rc;
my $s;
my $d;
my ($dh,@c);

############################################################################
## Create a domain
$R2 = $E1 . '<response>' . r(1001,'Command completed successfully; ' .
	'action pending') . $TRID . '</response>' . $E2;

my $cs = $dri->local_object('contactset');
$cs->add($dri->local_object('contact')->srid('TL1-TRAVEL'), 'tech');
$cs->add($dri->local_object('contact')->srid('SK1-TRAVEL'), 'admin');
eval {
	$rc = $dri->domain_create_only('jerusalem.travel', {
		ns => $dri->local_object('hosts')->add('dns1.syhosting.ch'),
		contact => $cs,
		duration => new DateTime::Duration(years => 2),
		auth => { pw => 'bulle.com' },
		uin => 235});
};
print(STDERR $@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'domain create');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><create><domain:create xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>jerusalem.travel</domain:name><domain:period unit="y">2</domain:period><domain:ns><domain:hostObj>dns1.syhosting.ch</domain:hostObj></domain:ns><domain:contact type="admin">SK1-TRAVEL</domain:contact><domain:contact type="tech">TL1-TRAVEL</domain:contact><domain:authInfo><domain:pw>bulle.com</domain:pw></domain:authInfo></domain:create></create><extension><neulevel:extension xmlns:neulevel="urn:ietf:params:xml:ns:neulevel-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:neulevel-1.0 neulevel-1.0.xsd"><neulevel:unspec>UIN=235</neulevel:unspec></neulevel:extension></extension><clTRID>ABC-12345</clTRID></command></epp>', 'domain create xml');

## Renew a domain
$R2 = $E1 . '<response>' . r(1001,'Command completed successfully; ' .
	'action pending') . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->domain_renew('muenchhausen-airlines.travel', {
		current_expiration => new DateTime(year => 2006, month => 12,
			day => 24),
		duration => new DateTime::Duration(years => 2),
		uin => 423});
};
print(STDERR $@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'domain renew');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><renew><domain:renew xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>muenchhausen-airlines.travel</domain:name><domain:curExpDate>2006-12-24</domain:curExpDate><domain:period unit="y">2</domain:period></domain:renew></renew><extension><neulevel:extension xmlns:neulevel="urn:ietf:params:xml:ns:neulevel-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:neulevel-1.0 neulevel-1.0.xsd"><neulevel:unspec>UIN=423</neulevel:unspec></neulevel:extension></extension><clTRID>ABC-12345</clTRID></command></epp>', 'domain renew xml');

## Restore a deleted domain
$R2 = $E1 . '<response>' . r(1001,'Command completed successfully; ' .
	'action pending') . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->domain_renew('deleted-by-accident.travel', {
		current_expiration => new DateTime(year => 2008, month => 12,
			day => 24),
		rgp => { code => 1, comment => 'Deleted by mistake'},
		uin => 423});
};
print(STDERR $@->as_string()) if ($@);
isa_ok($rc, 'Net::DRI::Protocol::ResultStatus');
is($rc->is_success(), 1, 'domain restore');
is($R1, '<?xml version="1.0" encoding="UTF-8" standalone="no"?><epp xmlns="urn:ietf:params:xml:ns:epp-1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="urn:ietf:params:xml:ns:epp-1.0 epp-1.0.xsd"><command><renew><domain:renew xmlns:domain="urn:ietf:params:xml:ns:domain-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:domain-1.0 domain-1.0.xsd"><domain:name>deleted-by-accident.travel</domain:name><domain:curExpDate>2008-12-24</domain:curExpDate></domain:renew></renew><extension><neulevel:extension xmlns:neulevel="urn:ietf:params:xml:ns:neulevel-1.0" xsi:schemaLocation="urn:ietf:params:xml:ns:neulevel-1.0 neulevel-1.0.xsd"><neulevel:unspec>RestoreReasonCode=1 RestoreComment=DeletedByMistake TrueData=Y ValidUse=Y UIN=423</neulevel:unspec></neulevel:extension></extension><clTRID>ABC-12345</clTRID></command></epp>', 'domain restore xml');

####################################################################################################
## Various poll messages
$R2 = $E1 . '<response><result code="1000"><msg lang="en-US">Command completed successfully</msg><value><text>SRS Major Code: 2000</text></value><value><text>SRS Minor Code: 20025</text></value><value><text>--MESSAGE_SUCCESSFULLY_DEQUEUED</text></value><value><text>4242342</text></value></result><msgQ id="4242342" count="5"><msg>4242342</msg></msgQ>' . $TRID . '</response>' . $E2;

eval {
	$rc = $dri->message_retrieve();
};
if ($@)
{
	if (ref($@) eq 'Net::DRI::Exception')
	{
		die($@->as_string());
	}
	else
	{
		die($@);
	}
}
is($rc->is_success(), 1, 'message polled successfully');

####################################################################################################
exit(0);

sub r
{
 my ($c,$m)=@_;
 return '<result code="'.($c || 1000).'"><msg>'.($m || 'Command completed successfully').'</msg></result>';
}