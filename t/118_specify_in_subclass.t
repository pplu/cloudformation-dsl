#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Data::Dumper;

package BaseClass {
  use CloudFormation::DSL;

  resource Instance => 'AWS::EC2::Instance', {
    'ImageId' => SpecifyInSubClass,
  };
}

package ValidInstance {
  use CloudFormation::DSL;
  extends 'BaseClass';

  resource '+Instance' => 'AWS::EC2::Instance', {
    '+ImageId' => 'ami-123456',
  };
}

package DynamicInstance {
  use CloudFormation::DSL;
  extends 'BaseClass';

  resource '+Instance' => 'AWS::EC2::Instance', {
    '+ImageId' => Cfn::DynamicValue->new(Value => sub { 'ami-654321' }),
  };
}

my $base = BaseClass->new;
throws_ok(sub { $base->as_hashref }, qr/You must specify a value/);

my $valid = ValidInstance->new;
cmp_ok($valid->as_hashref->{ Resources }->{ Instance }->{ Properties }->{ ImageId }, 'eq', 'ami-123456');

my $dynamic = DynamicInstance->new;
cmp_ok($dynamic->as_hashref->{ Resources }->{ Instance }->{ Properties }->{ ImageId }, 'eq', 'ami-654321');

done_testing();
