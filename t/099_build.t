#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

package TestClass {
  use CloudFormation::DSL;

  parameter stack_param => 'String', { Required => 1  }, { InStack => 1 };
  parameter instance_type => 'String', { Default => 'x1.xlarge' };

  resource Instance => 'AWS::EC2::Instance', {
    ImageId => 'ami-XXXXXX', 
    InstanceType => Parameter('instance_type'),
    SecurityGroups => [ 'sg-XXXXX' ],
  };

  output 'instanceid' => Ref('Instance');

  before build => sub {
    my $self = shift;
    $self->addResourceMetadata('Instance', MyMetadata => 'MyValue');
  };
}

my $obj = TestClass->new;
ok($obj->Resource('Instance'), 'Instance object is defined just after create');
ok($obj->Output('instanceid'), 'Output is defined just after create');

# This is a regression test: CCfnX::Shortcuts was making 'Parameter' behave in strange ways
# (overriding its behaviour)
isa_ok($obj->Parameter('stack_param'), 'Cfn::Parameter');

my $struct = $obj->as_hashref;

is_deeply($struct->{Resources}{Instance}{Metadata}, { MyMetadata => 'MyValue' }, 'Got the correct metadata');
is_deeply($struct->{Resources}{Instance}{Properties}{InstanceType}, 'x1.xlarge', 'Got the instance type through Parameter shortcut');

done_testing;
