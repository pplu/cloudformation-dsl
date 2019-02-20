#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

package TestClass {
  use CloudFormation::DSL;

  resource 'R1' => 'AWS::IAM::User', {
    Path => '/X',
  };

  has moose_attribute => (is => 'ro', isa => 'Str', default => 'X');
}

{
  my $o = TestClass->new;
  isa_ok($o, 'TestClass');
  isa_ok($o, 'CloudFormation::DSL::Object');
  isa_ok($o, 'Cfn');
  isa_ok($o->path_to('Resources.R1'), 'Cfn::Resource::AWS::IAM::User');
  cmp_ok($o->path_to('Resources.R1.Properties.Path')->Value, 'eq', '/X');
  cmp_ok($o->moose_attribute, 'eq', 'X', 'Moose attributes work too!');
}

{
  my $o = TestClass->new(moose_attribute => 'Y');
  cmp_ok($o->moose_attribute, 'eq', 'Y', 'Moose attributes can be specified in the constructor');
}

done_testing;
