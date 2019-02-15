#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::RealBin/../lib";
use lib "$FindBin::RealBin/../local/lib/perl5";

use Test::More;
use Test::Trap;
use CCfnX::Shortcuts;

is_deeply(
  Fn::Join('-', 'Value1', 'Value2'),
  { 'Fn::Join' => [ '-', [ 'Value1', 'Value2' ] ] },
  'Join used as function'
);
is_deeply(
  Fn::Base64('This is a base64 string'),
  { 'Fn::Base64' => 'This is a base64 string' },
  'Base64 used as Function'
);

is_deeply(
  Fn::Cidr('1.1.1.1', 2, 16),
  { 'Fn::Cidr' => [ '1.1.1.1', 2, 16 ] }
);

is_deeply(
  Fn::Cidr('1.1.1.1', 2),
  { 'Fn::Cidr' => [ '1.1.1.1', 2 ] }
);


my @versions = ('trusty', 'xenial');
my $ami;

foreach my $v (@versions) {
    $ami = FindUbuntuImage('eu-west-1', 'xenial');
    like($ami, qr/ami-/, ucfirst($v) . " AMI is found");
}

my @r;

@r = trap { $ami = FindUbuntuImage };
like($trap->die, qr/Need Region/, "FindUbuntuImage() dies because a lack of region");

@r = trap { $ami = FindUbuntuImage('eu-west-1') };
like($trap->die, qr/Need Version/, "FindUbuntuImage(region) dies because lack of version");

@r = trap { $ami = FindUbuntuImage('eu-west-1', 'blergh') };
like($trap->die, qr/Did not find an image/, "FindUbuntuImage(region, blergh) dies because not found version");

done_testing;
