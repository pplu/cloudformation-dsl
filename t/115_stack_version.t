#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

package TestClass {
  use CloudFormation::DSL;
  use CCfnX::CommonArgs;
  use CCfnX::InstanceArgs;

  has params => (is => 'ro', isa => 'CCfnX::CommonArgs', default => sub { CCfnX::InstanceArgs->new(
    instance_type => 'x1.xlarge',
    region => 'eu-west-1',
    account => 'devel-capside',
    name => 'NAME'
  ); } );

  stack_version 42;

  resource R1 => 'AWS::IAM::User', {};
}

my $obj = TestClass->new;

cmp_ok($obj->Metadata->{ StackVersion }->Value, 'eq', 42);
throws_ok(sub {
  $obj->addMetadata('StackVersion', 43);
}, qr/A metadata item named StackVersion already exists/);

my $struct = $obj->as_hashref;

is_deeply($struct->{ Resources }->{ R1 }, { Type => 'AWS::IAM::User', Properties => {} });
is_deeply($struct->{ Metadata }, { StackVersion => 42 });

throws_ok(sub {
  package TestClass2 {
    use CloudFormation::DSL;
    use CCfnX::CommonArgs;
    use CCfnX::InstanceArgs;
  
    has params => (is => 'ro', isa => 'CCfnX::CommonArgs', default => sub { CCfnX::InstanceArgs->new(
      instance_type => 'x1.xlarge',
      region => 'eu-west-1',
      account => 'devel-capside',
      name => 'NAME'
    ); } );
  
    stack_version 42;
    stack_version 43;
  
    resource R1 => 'AWS::IAM::User', {};
  }
}, qr/duplicate stack_version/);

done_testing;
