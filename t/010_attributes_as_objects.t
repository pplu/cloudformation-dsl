#!/usr/bin/env perl

use strict;
use warnings;

use Data::Printer;
use Test::More;

use Cfn;

package TestClass {
  use CloudFormation::DSL;
  use CCfnX::InstanceArgs;

  has params => (is => 'ro', isa => 'CCfnX::InstanceArgs', default => sub { CCfnX::InstanceArgs->new(
    instance_type => 'x1.xlarge',
    region => 'eu-west-1',
    account => 'devel-capside',
    name => 'NAME'
  ); } );

  resource R1 => 'AWS::AutoScaling::AutoScalingGroup', {
    MetricsCollection => [ { Granularity => 'X', Metrics => [ 'XXX', 'YYY' ] } ],
    MaxSize => 1,
    MinSize => 1,
    Tags => [ { Key => 'xKey', Value => 'xValue', PropagateAtLaunch => 1 }, { Key => 'yKey', Value => 'yValue', PropagateAtLaunch => 0 } ],
  };

  mapping Map1 => {
    key1 => 'value1',
  };

  # Testing a resource with generic tags
  resource LB1 => 'AWS::ElasticLoadBalancing::LoadBalancer', {
    Listeners => [
      { InstancePort => 1000, LoadBalancerPort => 1000, Protocol => 'TCP' },
    ],
    Tags => [
      { Key => 'k1', Value => 'v1' },
    ]
  };

  # Whole generic tags object looked up with a function
  resource LB2 => 'AWS::ElasticLoadBalancing::LoadBalancer', {
    Listeners => [
      { InstancePort => 1000, LoadBalancerPort => 1000, Protocol => 'TCP' },
    ],
    Tags => { "Fn::FindInMap" => [ 'Map1', 'key1' ] },
  };

  # Generic tags looked up with a function
  resource LB3 => 'AWS::ElasticLoadBalancing::LoadBalancer', {
    Listeners => [
      { InstancePort => 1000, LoadBalancerPort => 1000, Protocol => 'TCP' },
    ],
    Tags => [
      { "Fn::FindInMap" => [ 'Map1', 'key1' ] },
    ]
  };


  # Object property that is not an array
  resource UP1 => 'AWS::ApiGateway::UsagePlan', {
    Quota => {
      Limit => 100,
      Period => 'DAY',
    },
  };

  # Object property that is not an array looked up with a function
  resource UP2 => 'AWS::ApiGateway::UsagePlan', {
    Quota => { "Fn::FindInMap" => [ 'Map1', 'key1' ] },
  };

  # Array property that holds a complex object
  resource ASG1 => 'AWS::AutoScaling::AutoScalingGroup', {
    MetricsCollection => { "Fn::FindInMap" => [ 'Map1', 'key1' ] },
    MaxSize => 1,
    MinSize => 1,
    NotificationConfigurations => [
      { NotificationTypes => [ 'autoscaling:EC2_INSTANCE_LAUNCH_ERROR' ], TopicARN => 'arn' }
    ],
  };

  # Array property that holds a complex object: an element can be looked up with a function
  resource ASG2 => 'AWS::AutoScaling::AutoScalingGroup', {
    MaxSize => 1,
    MinSize => 1,
    NotificationConfigurations => [
      { 'Fn::FindInMap' => [ 'MAP', 'TLK' ] }
    ],
  };

 
  # Array property that holds a complex object: the whole array can be looked up with a function
  resource ASG3 => 'AWS::AutoScaling::AutoScalingGroup', {
    MetricsCollection => { "Fn::FindInMap" => [ 'Map1', 'key1' ] },
    MaxSize => 1,
    MinSize => 1,
    NotificationConfigurations => { 'Fn::FindInMap' => [ 'MAP', 'TLK' ] },
  };

  resource R3 => 'AWS::Events::Rule', {
    Targets => [ {
      Arn => 'arn',
      Id => 'id1',
    } ],    
  };

  # resource with a shared definition between properties (Egress and Ingress rules are the same type)
  resource SG1 => 'AWS::EC2::SecurityGroup', {
    GroupDescription => 'SG1 desc',
    SecurityGroupEgress => [
      {
        CidrIp => '1.2.3.4/32',
        FromPort => 1000,
        IpProtocol => 'TCP',
        ToPort => 1000,
      }
    ],
    SecurityGroupIngress => [
      {
        CidrIp => '1.2.3.4/32',
        FromPort => 1000,
        IpProtocol => 'TCP',
        ToPort => 1000,
      }
    ],
    Tags => [
     { Key => 'K1', Value => 'V1' },  
     { Key => 'K2', Value => 'V2' },  
    ],
    VpcId => 'vpc-12345'
  }

}

my $obj = TestClass->new;

isa_ok($obj->Resource('UP1')->Properties->Quota, 
       'Cfn::Resource::Properties::AWS::ApiGateway::UsagePlan::QuotaSettingsValue'
);

isa_ok($obj->Resource('LB1')->Properties->Tags, 'Cfn::Value::Array');
isa_ok($obj->Resource('LB1')->Properties->Tags->Value->[0], 'Cfn::Resource::Properties::Tag');

isa_ok($obj->Resource('LB2')->Properties->Tags, 'Cfn::Value::Function');

isa_ok($obj->Resource('LB3')->Properties->Tags, 'Cfn::Value::Array');
isa_ok($obj->Resource('LB3')->Properties->Tags->Value->[0], 'Cfn::Value::Function');

isa_ok($obj->Resource('R1')->Properties->MetricsCollection, 'Cfn::Value::Array');
isa_ok($obj->Resource('ASG1')->Properties->MetricsCollection, 'Cfn::Value::Function');

isa_ok($obj->Resource('ASG1')->Properties->NotificationConfigurations, 'Cfn::Value::Array');
isa_ok($obj->Resource('ASG2')->Properties->NotificationConfigurations, 'Cfn::Value::Array');
isa_ok($obj->Resource('ASG3')->Properties->NotificationConfigurations, 'Cfn::Value::Function');

isa_ok($obj->Resource('ASG1')->Properties->NotificationConfigurations->Value->[0], 'Cfn::Resource::Properties::AWS::AutoScaling::AutoScalingGroup::NotificationConfigurationValue');
isa_ok($obj->Resource('ASG2')->Properties->NotificationConfigurations->Value->[0], 'Cfn::Value::Function');

isa_ok($obj->Resource('R3')->Properties->Targets->Value->[0], 'Cfn::Resource::Properties::AWS::Events::Rule::TargetValue');

isa_ok($obj->Resource('R1')->Properties->Tags->Value->[0], 'Cfn::Resource::Properties::AWS::AutoScaling::AutoScalingGroup::TagPropertyValue');
isa_ok($obj->Resource('SG1')->Properties->Tags->Value->[0], 'Cfn::Resource::Properties::Tag');

isa_ok($obj->Resource('SG1')->Properties->SecurityGroupEgress,  'Cfn::Value::Array');
isa_ok($obj->Resource('SG1')->Properties->SecurityGroupEgress->Value->[0],  'Cfn::Resource::Properties::AWS::EC2::SecurityGroup::EgressValue');
isa_ok($obj->Resource('SG1')->Properties->SecurityGroupIngress, 'Cfn::Value::Array');
isa_ok($obj->Resource('SG1')->Properties->SecurityGroupIngress->Value->[0], 'Cfn::Resource::Properties::AWS::EC2::SecurityGroup::IngressValue');



my $struct = $obj->as_hashref;

cmp_ok($struct->{Resources}{R1}{Properties}{MetricsCollection}->[0]->{Granularity}, 'eq', 'X', 'Got a granularity');
cmp_ok($struct->{Resources}{R1}{Properties}{MetricsCollection}->[0]->{Metrics}->[0], 'eq', 'XXX', 'Got a metric XXX');
cmp_ok($struct->{Resources}{R1}{Properties}{MetricsCollection}->[0]->{Metrics}->[1], 'eq', 'YYY', 'Got a metric YYY');

cmp_ok($struct->{Resources}{UP1}{Properties}{Quota}->{Limit},  '==', 100,   'Got UP1s Limit');
cmp_ok($struct->{Resources}{UP1}{Properties}{Quota}->{Period}, 'eq', 'DAY', 'Got UP1s Period');

cmp_ok($struct->{Resources}{ASG1}{Properties}{NotificationConfigurations}->[0]->{NotificationTypes}->[0], 'eq', 'autoscaling:EC2_INSTANCE_LAUNCH_ERROR', 'Got a notification type');
cmp_ok($struct->{Resources}{ASG1}{Properties}{NotificationConfigurations}->[0]->{TopicARN}, 'eq', 'arn', 'Got an arn');

cmp_ok($struct->{Resources}{R1}{Properties}{Tags}->[0]->{Key}, 'eq', 'xKey', 'Got a key for first tag');
cmp_ok($struct->{Resources}{R1}{Properties}{Tags}->[0]->{Value}, 'eq', 'xValue', 'Got a value for first tag');
cmp_ok($struct->{Resources}{R1}{Properties}{Tags}->[1]->{Key}, 'eq', 'yKey', 'Got a key for second tag');
cmp_ok($struct->{Resources}{R1}{Properties}{Tags}->[1]->{Value}, 'eq', 'yValue', 'Got a value for second tag');

cmp_ok($struct->{Resources}{SG1}{Properties}{Tags}->[0]->{Key}, 'eq', 'K1', 'Got a key for first tag');
cmp_ok($struct->{Resources}{SG1}{Properties}{Tags}->[0]->{Value}, 'eq', 'V1', 'Got a value for second tag');
cmp_ok($struct->{Resources}{SG1}{Properties}{Tags}->[1]->{Key}, 'eq', 'K2', 'Got a key for first tag');
cmp_ok($struct->{Resources}{SG1}{Properties}{Tags}->[1]->{Value}, 'eq', 'V2', 'Got a value for second tag');


cmp_ok($struct->{Resources}{LB1}{Properties}{Tags}->[0]->{Key}, 'eq', 'k1', 'Got a key for first tag');
cmp_ok($struct->{Resources}{LB1}{Properties}{Tags}->[0]->{Value}, 'eq', 'v1', 'Got a value for second tag');

is_deeply(
  $struct->{Resources}{LB2}{Properties}{Tags}, 
  { 'Fn::FindInMap' => [ 'Map1', 'key1' ]},
  'Got a function for the whole tag object');

is_deeply(
  $struct->{Resources}{LB3}{Properties}{Tags}->[0], 
  { 'Fn::FindInMap' => [ 'Map1', 'key1' ]},
  'Got a function for the first element of tag object');

done_testing;
