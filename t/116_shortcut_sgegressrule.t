#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
$Data::Dumper::Indent=1;

{
  package TestClass {
    use CloudFormation::DSL;

    resource SGDestination => 'AWS::EC2::SecurityGroup', {
      GroupDescription => 'Test SG to be used as a Ref() destination',
      VpcId => 'vpc-deadbeef',
    };


    resource SGI => 'AWS::EC2::SecurityGroup', {
      GroupDescription => "SG group test",
      VpcId => 'vpc-deadbeef',
      SecurityGroupEgress => [
        SGEgressRule('12345', '10.0.0.0/32'),
      ],
    };

    resource SGII => 'AWS::EC2::SecurityGroup', {
      GroupDescription => "SG group test",
      VpcId => 'vpc-deadbeef',
      SecurityGroupEgress => [
        SGEgressRule('12345', Ref('SGDestination')),
      ],
    };

  }

  my $resources = TestClass->new()->as_hashref->{Resources};

  is_deeply($resources->{SGI}{Properties}{SecurityGroupEgress},
    [
      {
        'FromPort' => '12345',
        'IpProtocol' => 'tcp',
        'CidrIp' => '10.0.0.0/32',
        'ToPort' => '12345'
      }
    ],
     "The rule is correctly generated");

  is_deeply($resources->{SGII}{Properties}{SecurityGroupEgress},
    [
      {
        'FromPort' => '12345',
        'IpProtocol' => 'tcp',
          'DestinationSecurityGroupId' => {
            'Ref' => 'SGDestination'
          },
        'ToPort' => '12345'
      }
    ],
     "The rule with a Ref is correctly generated");

}

done_testing();
