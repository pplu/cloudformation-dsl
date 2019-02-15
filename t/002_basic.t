#!/usr/bin/env perl

use Test::More;

package TestClass {
  use CloudFormation::DSL;

  resource 'R1' => 'AWS::IAM::User', {
    Path => '/X',
  };
}

{
  my $o = TestClass->new;
  isa_ok($o, 'TestClass');
  isa_ok($o, 'CloudFormation::DSL::Object');
  isa_ok($o, 'Cfn');
  isa_ok($o->path_to('Resources.R1'), 'Cfn::Resource::AWS::IAM::User');
  cmp_ok($o->path_to('Resources.R1.Properties.Path')->Value, 'eq', '/X');
}

done_testing;
