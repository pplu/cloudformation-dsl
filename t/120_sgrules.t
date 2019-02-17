#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
#
# This test is designed to verify that the SGRule shortcut generates the proper type of
# destination depending on the second parameter. That could be an IP address (v4 or
# v6, a Ref() or a Parameter()

package Params {
    use Moose;
    with 'MooseX::Getopt';

    # Literal string, this should generate a SourceSecurityGroupIngress
    has sgname => (is => 'ro', isa => 'Str', required => 1);

}

package TestClass {
    use CloudFormation::DSL;

    has params => (is => 'ro', isa => 'Params',
            default => sub { Params->new( sgname => 'sg-dabacabab') });

    resource SGSource => 'AWS::EC2::SecurityGroup', {
        GroupDescription => 'Test SG to be used as a Ref() source',
        VpcId => 'vpc-deadbeef',
    };

    resource SGRef => 'AWS::EC2::SecurityGroup', {
        GroupDescription => "SG group test",
        VpcId => 'vpc-deadbeef',
        SecurityGroupIngress => [
            SGRule(1, Ref('SGSource')),
        ],
    };

    resource SGParam => 'AWS::EC2::SecurityGroup', {
        GroupDescription => "SG group test",
        VpcId => 'vpc-deadbeef',
        SecurityGroupIngress => [
            SGRule(2, Parameter('sgname')),
        ],
    };

    resource SGIpv4 => 'AWS::EC2::SecurityGroup', {
        GroupDescription => "SG group test",
        VpcId => 'vpc-deadbeef',
        SecurityGroupIngress => [
            SGRule(3, '10.17.0.0/22'),
        ],
    };

    resource SGIpv6 => 'AWS::EC2::SecurityGroup', {
        GroupDescription => "SG group test",
        VpcId => 'vpc-deadbeef',
        SecurityGroupIngress => [
            SGRule(4, '2001:0db8:85a3:0000:0000:8a2e:0370:7334/128'),
        ],
    };

}

my $resources = TestClass->new()->as_hashref->{Resources};

is_deeply($resources->{SGRef}{Properties}{SecurityGroupIngress}[0]{SourceSecurityGroupId},
        { 'Ref' => 'SGSource' }, "Using a Ref generates a Ref to a SG");
is_deeply($resources->{SGParam}{Properties}{SecurityGroupIngress}[0]{SourceSecurityGroupId},
        'sg-dabacabab', "A Parameter generates a Ref to a SG");
is_deeply($resources->{SGIpv4}{Properties}{SecurityGroupIngress}[0]{CidrIp},
        '10.17.0.0/22', "A scalar lookling like an IPv4 generates a CidrIp");
is_deeply($resources->{SGIpv6}{Properties}{SecurityGroupIngress}[0]{CidrIpv6},
        '2001:0db8:85a3:0000:0000:8a2e:0370:7334/128', "A scalar lookling like an IPv6 generates a CidrIpv6");

# SGRule misc tests
use CloudFormation::DSL qw/SGRule ELBListener TCPELBListener/;
use Data::Dumper;
my $rule;

$rule = SGRule(80, '0.0.0.0/0');
is($rule->{IpProtocol}, 'tcp', 'SGRule sets tcp as default in the two parameter form');
ok(!defined $rule->{Description}, 'The Description field is not set in the two parameter form');

$rule = SGRule(80, '0.0.0.0/0', 'udp');
is($rule->{IpProtocol}, 'udp', 'SGRule sets the protocol in the basic three parameter form');
ok(!defined $rule->{Description}, 'The Description field is not set in the basic three parameter form');

my $desc = 'Description rule';
$rule = SGRule(80, '0.0.0.0/0', $desc);
is($rule->{IpProtocol}, 'tcp', 'SGRule uses the default protocol if the third parameter is not an IP known protocol or number');
is($rule->{Description}, $desc, 'SGRule sets the Description fileld with the right value');

$rule = SGRule(80, '0.0.0.0/0', 'icmp', $desc);
is($rule->{IpProtocol}, 'icmp', 'SGRule sets the right protocol in the full 4-parameter form');
is($rule->{Description}, $desc, 'SGRule sets the Description fileld with the right value in the full 4-parameter form');

$rule = SGRule(80, '0.0.0.0/0', 50);
is($rule->{IpProtocol}, 50, 'SGRule sets the right numeric protocol in the 3-param form');
ok(!defined $rule->{Description}, 'The Description field is not set with numeric IP protocols in 3-parameters');

$rule = SGRule(80, '0.0.0.0/0', 50, $desc);
is($rule->{IpProtocol}, 50, 'SGRule sets the right numeric protocol in the full 4-parameter form');
is($rule->{Description}, $desc, 'SGRule sets the Description fileld with the right value');

# Test for descriptions that might look like numbers, to avoid detect them as
# protocols
$desc = '-1desc1';
$rule = SGRule(80, '0.0.0.0/0', $desc);
is($rule->{IpProtocol}, 'tcp', 'SGRule sets the right protocol for desc with numbers');
is($rule->{Description}, $desc, 'SGRule sets the Description fileld with the right value');

$desc = 'desc50desc';
$rule = SGRule(80, '0.0.0.0/0', $desc);
is($rule->{IpProtocol}, 'tcp', 'SGRule sets the right protocol for desc with numbers');
is($rule->{Description}, $desc, 'SGRule sets the Description fileld with the right value');

{
  my $list = ELBListener(80, 'HTTP');
  is_deeply(
    $list,
    { InstancePort => 80, InstanceProtocol => 'HTTP', LoadBalancerPort => 80, Protocol => 'HTTP' },
    '2 param ELBListener HTTP balancer',
  );
}

{
  my $list = ELBListener(80, 'HTTP', 8080);
  is_deeply(
    $list,
    { InstancePort => 8080, InstanceProtocol => 'HTTP', LoadBalancerPort => 80, Protocol => 'HTTP' },
    '3 param ELBListener HTTP balancer. Elb listens on 80 and passes requests to 8080 on backends',
  );
}

{
  my $list = ELBListener(443, 'HTTPS', 80, 'HTTP');
  is_deeply(
    $list,
    { InstancePort => 80, InstanceProtocol => 'HTTP', LoadBalancerPort => 443, Protocol => 'HTTPS' },
    '4 param ELBListener HTTPS Offload',
  );
}

{
  my $list = TCPELBListener(3000);
  is_deeply(
    $list,
    { InstancePort => 3000, InstanceProtocol => 'TCP', LoadBalancerPort => 3000, Protocol => 'TCP' },
    '1 param TCPELBListener. Balance on port 3000',
  );
}

{
  my $list = TCPELBListener(3000, 6000);
  is_deeply(
    $list,
    { InstancePort => 6000, InstanceProtocol => 'TCP', LoadBalancerPort => 3000, Protocol => 'TCP' },
    '2 param TCPELBListener. Balance on port 3000 to backends on port 6000',
  );
}

done_testing;
