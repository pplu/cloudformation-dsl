#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

package TestClass {
  use CloudFormation::DSL;
  use CCfnX::CommonArgs;

  # This is not known to be valid
  #metadata 'MyMDTest1', Ref('XXX');
  #metadata 'MyMDTest2', 'String';
  #metadata 'MyMDTest3', { a => 'hash' };
  #metadata 'MyMDTest4', [ 1,2,3,4 ];

  metadata 'MyMDTest5', { key1 => 'X' };
  metadata 'MyMDTest6', { key1 => Ref('XXX') };
}

my $obj = TestClass->new;
my $struct = $obj->as_hashref;

# This is not known to be valid
#is_deeply(
#  $struct->{Metadata}->{ MyMDTest1 },
#  { Ref => 'XXX' },
#  'Got a Ref in MyMDTest1'
#);
#
#cmp_ok(
#  $struct->{Metadata}->{ MyMDTest2 },
#  'eq', 'String',
#  'Got a string in MyMDTest2'
#);
#
#is_deeply(
#  $struct->{Metadata}->{ MyMDTest3 },
#  { a => 'hash' },
#  'Got a hash in MyMDTest3'
#);
#
#is_deeply(
#  $struct->{Metadata}->{ MyMDTest4 },
#  [ 1,2,3,4 ],
#  'Got an array in MyMDTest4'
#);

is_deeply(
  $struct->{Metadata}->{ MyMDTest5 },
  { key1 => 'X' },
  'Got a Ref in MyMDTest5'
);

is_deeply(
  $struct->{Metadata}->{ MyMDTest6 },
  { key1 => { Ref => 'XXX' } },
  'Got a Ref in MyMDTest6'
);

# addMetadata method passing the whole metadata object
my $cfn = Cfn->new;
$cfn->addMetadata({ 'k1' => 'v1' });
my $hr = $cfn->as_hashref;
is_deeply($hr,{Resources=>{},Metadata=>{k1=>'v1'}});

throws_ok(sub {
  package TestClass {
    use CloudFormation::DSL;
  
    metadata 'MyMDTest5', { key1 => 'X' };
    metadata 'MyMDTest5', { key1 => Ref('XXX') };
  }
}, qr/Redeclared/);

done_testing;
