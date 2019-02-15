#!/usr/bin/env perl

use Test::More;

use CCfn;

package TestClassParams {
  use Moose;
  extends 'CCfnX::InstanceArgs';
  has 'stack_param' => (is => 'ro', isa => 'Str', required => 1, traits => [ 'StackParameter' ]);
}

package TestClass {
  use Moose;
  extends 'CCfn';
  use CCfnX::InstanceArgs;
  use CCfnX::Shortcuts;

  has params => (is => 'ro', isa => 'TestClassParams', default => sub { TestClassParams->new(
    instance_type => 'x1.xlarge',
    region => 'eu-west-1',
    account => 'devel-capside',
    name => 'NAME',
    stack_param => 'VALUE',
  ); } );

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
