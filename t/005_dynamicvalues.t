#!/usr/bin/env perl

use strict;
use warnings;
use Data::Printer;
use Test::More;
use Test::Exception;

package TestClass {
  use CloudFormation::DSL;
  # So we can use Test::More in the dynamic values
  use Test::More;

  parameter instance_type => 'String', { Default => 'x1.xlarge' };

  resource ELB => 'AWS::ElasticLoadBalancing::LoadBalancer', {
    AccessLoggingPolicy => {
      Enabled => 1,
      S3BucketName => Cfn::DynamicValue->new(Value => sub {
        isa_ok($_[0], 'TestClass', 'A DynamicValue inside a TypedValue recieves as first parameter a reference to the infrastructure');
        return 'the-bucket';
      }), 
    },
    Listeners => [
    ],
  };

  resource IAM => 'AWS::IAM::User', {
    Path => Cfn::DynamicValue->new(Value => sub {
      my $self = shift;
      $self->add_to_stash('akey', 'akeyValue');
      return '/';
    })
  };

  resource Instance => 'AWS::EC2::Instance', sub {
    ImageId => Cfn::DynamicValue->new(Value => sub { return 'DynamicValue' }),
    InstanceType => Parameter('instance_type'),
    SecurityGroups => [ 'sg-XXXXX' ],
    AvailabilityZone => Cfn::DynamicValue->new(Value => sub {
      isa_ok($_[0], 'TestClass', 'A DynamicValue recieves as first parameter a reference to the infrastructure');
      return 'eu-west-2'
    }),
    UserData => {
      'Fn::Base64' => {
        'Fn::Join' => [
          '', [
            Cfn::DynamicValue->new(Value => sub { return 'line 1' }),
            Cfn::DynamicValue->new(Value => sub { return 'line 2' }),
            Cfn::DynamicValue->new(Value => sub { 
               Cfn::DynamicValue->new(Value => sub { return 'dv in a dv' })
            }),
            Cfn::DynamicValue->new(Value => sub { 
               return ('before dynamic', Cfn::DynamicValue->new(Value => sub { return 'in middle' }), 'after dynamic');
            }),
          ]
        ]
      }
    }
  };
}

my $obj = TestClass->new;
my $struct = $obj->as_hashref;

cmp_ok($struct->{Resources}{Instance}{Properties}{ImageId}, 'eq', 'DynamicValue', 'Got a correct DynamicValue');
cmp_ok($struct->{Resources}{ELB}{Properties}{AccessLoggingPolicy}{S3BucketName}, 'eq', 'the-bucket', 'Got correct DynamicValue from inside TypedValue');
cmp_ok($struct->{Resources}{Instance}{Properties}{InstanceType}, 'eq', 'x1.xlarge', 'Parameter(instance_type) working correctly');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][0], 'eq', 'line 1', 'userdata dv line 1');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][1], 'eq', 'line 2', 'userdata dv line 2');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][2], 'eq', 'dv in a dv', 'a dynamic value returns a dynamic value and gets resolved');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][3], 'eq', 'before dynamic', 'multiple dynamic returns');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][4], 'eq', 'in middle', 'multiple dynamic returns');
cmp_ok($struct->{Resources}{Instance}{Properties}{UserData}{'Fn::Base64'}{'Fn::Join'}[1][5], 'eq', 'after dynamic', 'multiple dynamic returns');
cmp_ok($struct->{Resources}{IAM}{Properties}{Path}, 'eq', '/', 'dynamic value that stashes');
cmp_ok($obj->stash->{ akey }, 'eq', 'akeyValue', 'The stashed value is in the stash');

package TestClass2 {
  use CloudFormation::DSL;

  resource IAM => 'AWS::IAM::User', {
    Path => Cfn::DynamicValue->new(Value => sub {
      my $self = shift;
      $self->add_to_stash('akey', 'akeyValue');
      return '/';
    })
  };

  resource IAM2 => 'AWS::IAM::User', {
    Path => Cfn::DynamicValue->new(Value => sub {
      my $self = shift;
      $self->add_to_stash('akey', 'akeyValue');
      return '/';
    })
  };
}

{
  my $o = TestClass2->new;
  throws_ok(sub { $o->as_hashref }, qr/already in the stash/);
}

done_testing;
