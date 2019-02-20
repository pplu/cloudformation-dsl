#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Moose::Util::TypeConstraints;

coerce 'Cfn::Resource::Properties::Test1',
  from 'HashRef',
   via { Cfn::Resource::Properties::Test1->new( %$_ ) };

package Cfn::Resource::Properties::Test1 {
  use Moose;
  extends 'Cfn::Resource::Properties';
  has Prop1 => (is => 'rw', isa => 'Cfn::Value', coerce => 1);
  has Prop2 => (is => 'rw', isa => 'Cfn::Value', coerce => 1);
}

package Cfn::Resource::Test1 {
  use Moose;
  extends 'Cfn::Resource';
  has Properties => (is => 'rw', isa => 'Cfn::Resource::Properties::Test1', required => 1, coerce => 1);
}

package TestClass {
  use CloudFormation::DSL;

  condition MyCondition => Fn::Equals(Ref('EnvType'), "prod");

  resource ResourceWithCondition => 'Test1', {
    Prop1 => 'Test',
    Prop2 => 'Test',
  }, {
    Condition => 'MyCondition',
  };

  output o1 => 'Output1';
  output o2 => 'Output2', { Condition => 'MyCondition' };
}

my $hr = TestClass->new->as_hashref;

is_deeply($hr->{Conditions}->{MyCondition}, { 'Fn::Equals' => [ { 'Ref' => 'EnvType' }, 'prod' ] }, 'MyCondition correctly returned');

ok(not(defined($hr->{Outputs}->{o1}->{Condition})), 'o1 doesnt have a Condition');
cmp_ok($hr->{Outputs}->{o2}->{Condition}, 'eq', 'MyCondition', 'o2 points to a Condition');

ok(not(defined($hr->{Resources}->{ResourceWithoutCondition}->{Condition})), 'ResourceWithoutCondition doesnt have a Condition');
cmp_ok($hr->{Resources}->{ResourceWithCondition}->{Condition}, 'eq', 'MyCondition', 'ResourceWithCondition has a Condition');

done_testing;
