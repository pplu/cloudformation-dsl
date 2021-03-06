#/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Cfn::Diff;

package Test401::Stack1 {
  use CloudFormation::DSL;

  resource r1 => 'AWS::EC2::Instance', {
    ImageId => 'X',
  }
}

package Test401::Stack1ChangeR1 {
  use CloudFormation::DSL;

  resource r1 => 'AWS::IAM::User', {
  }
}


package Test401::Stack2 {
  use CloudFormation::DSL;

  resource r2 => 'AWS::EC2::Instance', {
    ImageId => 'Y',
  }
}

package Test401::Stack3 {
  use CloudFormation::DSL;

  resource r1 => 'AWS::EC2::Instance', {
    ImageId => 'Y',
  }
}

package Test401::Stack4 {
  use CloudFormation::DSL;

  resource r1 => 'AWS::EC2::Instance', {
    ImageId => 'Y',
    KeyName => 'test_key',
  }
}

package Test401::Stack5 {
  use CloudFormation::DSL;

  resource r1 => 'AWS::EC2::Instance', {
    ImageId => 'Y',
    KeyName => 'test_key',
  }
}

package Test401::Stack6 {
  use CloudFormation::DSL;

  resource r1 => 'AWS::EC2::Instance', {
    ImageId => 'Y',
    KeyName => Ref('param'),
  }
}

package Test401::Stack7 {
  use CloudFormation::DSL;

  resource DNS => 'AWS::Route53::RecordSet', {
   HostedZoneName => Ref('ZoneName'),
   Name => { 'Fn::Join', [ '.', [ { 'Fn::Join' => [ '-', ['infra', Ref('ID') ] ] } , Ref('ZoneName') ] ] },
   Type => 'CNAME',
   TTL => 900,
   ResourceRecords => [
     GetAtt('ELB', 'DNSName')
   ],
  };
}

package Test401::Stack8 {
  use CloudFormation::DSL;
  
  parameter dns_type => 'String', { Default => 'CNAME' };

  resource DNS => 'AWS::Route53::RecordSet', {
   HostedZoneName => Ref('ZoneName'),
   Name => Fn::Join('.', Fn::Join('-', 'infra', Ref('ID')), Ref('ZoneName')),
   Type => Parameter('dns_type'),
   TTL => 900,
   ResourceRecords => [
     GetAtt('ELB', 'DNSName')
   ],
  };
}

package Test401::Stack9 {
  use CloudFormation::DSL;

  resource CR => 'AWS::CloudFormation::CustomResource', {
    ServiceToken => 'ST',
    Prop1 => 'X',
  }, {
    Version => "1.0",
  };
}

package Test401::Stack10 {
  use CloudFormation::DSL;

  resource CR => 'Custom::CR', {
    ServiceToken => 'ST',
    "Prop1" => 'Y',
    },{
      "Version" => 1.0
  };
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack1->new, right => Test401::Stack1->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 0, 'No changes for same stack');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack1->new, right => Test401::Stack2->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 2, '2 changes: 1 res added, 1 deleted');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack1->new, right => Test401::Stack3->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, '1 change: changed ImageId (Stack1 Vs Stack3)');
  isa_ok($diff->changes->[0], 'Cfn::Diff::ResourcePropertyChange','Got a ResourcePropertyChange');
  cmp_ok($diff->changes->[0]->mutability, 'eq', 'Immutable', 'ImageId prop is Immutable');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack3->new, right => Test401::Stack1->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, '1 change: changed ImageId (Stack3 vs Stack1)');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack1->new, right => Test401::Stack4->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 2, '2 changes: 2 props changed');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack4->new, right => Test401::Stack5->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 0, 'No changes');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack7->new, right => Test401::Stack7->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 0, 'No changes');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack5->new, right => Test401::Stack6->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, '1 prop changed from Primitive to Ref');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack7->new, right => Test401::Stack8->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, '1 props changed from hardcoded value to DynamicValue');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack8->new, right => Test401::Stack7->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, '1 props changed from DynamicValue to hardcoded value');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack9->new, right => Test401::Stack9->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 0, 'Custom resources are diffable');
}

{
  my $left = Test401::Stack10->new;
  $left->cfn_options->custom_resource_rename(1);
  my $right = Test401::Stack9->new;
  $right->cfn_options->custom_resource_rename(1);

  my $diff = Cfn::Diff->new(left => $left, right => $right);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, 'prop change in a custom resource');
  isa_ok($diff->changes->[0], 'Cfn::Diff::ResourcePropertyChange', 'Got a property change in a custom resource');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack10->new, right => Test401::Stack9->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, 'prop change in a custom resource');
  isa_ok($diff->changes->[0], 'Cfn::Diff::ResourcePropertyChange', 'Got a property change in a custom resource');
}

{
  my $diff = Cfn::Diff->new(left => Test401::Stack1->new, right => Test401::Stack1ChangeR1->new);
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, 'Resource type change detected');
  isa_ok($diff->changes->[0], 'Cfn::Diff::IncompatibleChange', 'Got an incompatible change');
}

my $withprops = '{"Resources" : {"IAMUser" : {"Type" : "AWS::IAM::User","Properties" : {}} }}';
my $withoutprops = '{"Resources" : {"IAMUser" : {"Type" : "AWS::IAM::User"} }}';

{
  my $diff = Cfn::Diff->new(
    left => Cfn->from_json($withprops),
    right => Cfn->from_json($withoutprops)
  );
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, 'got one change');
  isa_ok($diff->changes->[0], 'Cfn::Diff::Changes','Got a generic Change object');
  cmp_ok($diff->changes->[0]->path, 'eq', 'Resources.IAMUser', 'path ok');
  cmp_ok($diff->changes->[0]->change, 'eq', 'Properties key deleted', 'correct message');
}

{
  my $diff = Cfn::Diff->new(
    left => Cfn->from_json($withoutprops),
    right => Cfn->from_json($withprops)
  );
  cmp_ok(scalar(@{ $diff->changes }), '==', 1, 'got one change');
  isa_ok($diff->changes->[0], 'Cfn::Diff::Changes','Got a generic Change object');
  cmp_ok($diff->changes->[0]->path, 'eq', 'Resources.IAMUser', 'path ok');
  cmp_ok($diff->changes->[0]->change, 'eq', 'Properties key added', 'correct message');
}

{
  my $diff = Cfn::Diff->new(
    left => Cfn->from_json($withoutprops),
    right => Cfn->from_json($withoutprops)
  );
  cmp_ok(scalar(@{ $diff->changes }), '==', 0, 'got no changes');
}

done_testing;
