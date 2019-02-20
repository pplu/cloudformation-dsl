#!/usr/bin/env perl

use strict;
use warnings; 
use feature 'say';

use Moose::Util 'find_meta';
use Test::More;
use Test::Exception;

package AttachmentResolver {
  use Moose;
  with 'CloudFormation::DSL::AttachmentResolver';
  sub resolve { return 'STUB' }
}

package TestClass {
  use CloudFormation::DSL;

  parameter 'Param1' => 'String', {
    MaxLength   => 30,
    Default     => 'this is the default value',
    Description => 'Param1 Description',
  };

  parameter Param2 => 'String', {
    MaxLength   => 10,
    Description => 'Param2 Description',
  }, {
    InStack => 1
  };

  parameter Param3 => 'Number', {
    Default => sub { 314 },
    Description => 'Param3 description',
  };

  attachment Attach1 => 'AWS::EC2::Image::Id', {
    AttachParam1 => 'ip/address',
    -AttachParam2 => 'ip2/address',
  };
}

{
  my $p = TestClass->meta->find_attribute_by_name('Param1');
  ok(defined $p);
  ok($p->does('Parameter'), "The attribute 'Param1' has the Parameter trait");
}
{
  my $o = TestClass->new(attachment_resolver => AttachmentResolver->new);

  cmp_ok($o->ParameterCount, '==', 2);

  my $param1 = $o->Param1;
  isa_ok($param1, 'Cfn::Parameter', "'The attribute 'Param1' isa 'Cfn::Parameter'");
 
  is($param1->Type, 'String', "The attribute 'Param1' has a property 'Type' (set by 'parameter' function of 'CCfnX::Shortcuts')");
  is($param1->Default, 'this is the default value', "The attribute 'Param1' has a property 'Default'");
  is($param1->MaxLength, 30, "The attribute 'Param1' has a property 'MaxLength'");
  is($param1->Description, 'Param1 Description', "The attribute 'Param1' has a property 'Description'");
}

{  
  my $p = TestClass->meta->find_attribute_by_name('Param2');
  ok(defined $p, 'TestClass has a Param2 attribute');
  ok($p->does('Parameter'), "The attribute 'Param1' has the Parameter trait");
  ok($p->does('StackParameter'), "The attribute 'Param2' has the StackParameter trait");
}

{  
  my $p = TestClass->meta->find_attribute_by_name('Attach1');
  ok(defined $p, 'TestClass has a Attach1 attribute');
  ok($p->does('Attachable'), "The attribute 'Attach1' has the Attachable trait");
}

{  
  my $p = TestClass->meta->find_attribute_by_name('AttachParam1');
  ok(defined $p, 'TestClass has an AttachParam1 attribute');
  ok($p->does('Parameter'), "The attribute 'AttachParam1' has the Parameter trait");
  ok($p->does('StackParameter'), "The attribute 'AttachParam2' has the StackParameter trait");
}

package TestClass4Base {
  use CloudFormation::DSL;

  parameter 'Param1' => 'String', {
    MaxLength   => 30,
    Default     => 'param1 default',
    Description => 'Param1 Description',
  };

  parameter 'Param2' => 'String', {
    MaxLength   => 20,
    Default     => 'param2 default',
    Description => 'Param2 Description',
  };
}

{
  my $c1 = TestClass4Base->new;
  my $param1 = $c1->Param1;
  isa_ok($param1, 'Cfn::Parameter');
  is($param1->Type, 'String', "The attribute 'Param1' has a property 'Type' (set by 'parameter' function of 'CCfnX::Shortcuts')"); 
  is($param1->Default, 'param1 default', "The attribute 'Param1' has a property 'Default'");
  is($param1->MaxLength, 30, "The attribute 'Param1' has a property 'MaxLength'");
  is($param1->Description, 'Param1 Description', "The attribute 'Param1' has a property 'Description'");

  my $param2 = $c1->Param2;
  isa_ok($param2, 'Cfn::Parameter');
  is($param2->Type, 'String', "The attribute 'Param2' has a property 'Type' (set by 'parameter' function of 'CCfnX::Shortcuts')"); 
  is($param2->Default, 'param2 default', "The attribute 'Param2' has a property 'Default'");
  is($param2->MaxLength, 20, "The attribute 'Param2' has a property 'MaxLength'");
  is($param2->Description, 'Param2 Description', "The attribute 'Param2' has a property 'Description'");
}

package TestClass4 {
  use CloudFormation::DSL;
  extends 'TestClass4Base';

  parameter '+Param2' => 'Number', {
    MaxLength   => 35,
    Default     => 'this is the default value',
    Description => 'Param2 Description',
  };

  parameter Param3 => 'String', {
    Default => 40,
  };
}

{
  my $c1 = TestClass4->new;

  # same tests as TestClass4Base for Param1 (since it doesn't get overwritten)
  my $param1 = $c1->Param1;
  isa_ok($param1, 'Cfn::Parameter');
  is($param1->Type, 'String', "The attribute 'Param1' has a property 'Type' (set by 'parameter' function of 'CCfnX::Shortcuts')"); 
  is($param1->Default, 'param1 default', "The attribute 'Param1' has a property 'Default'");
  is($param1->MaxLength, 30, "The attribute 'Param1' has a property 'MaxLength'");
  is($param1->Description, 'Param1 Description', "The attribute 'Param1' has a property 'Description'");

  # Test overwritten parameters
  my $param2 = $c1->Param2;
  isa_ok($param2, 'Cfn::Parameter');
  is($param2->Type, 'Number', "The attribute 'Param2' has a property 'Type' (set by 'parameter' function of 'CCfnX::Shortcuts')"); 
  is($param2->Default, 'this is the default value', "The attribute 'Param2' has a property 'Default'");
  is($param2->MaxLength, 35, "The attribute 'Param2' has a property 'MaxLength'");
  is($param2->Description, 'Param2 Description', "The attribute 'Param2' has a property 'Description'");


  my $param3 = $c1->Param3;
  isa_ok($param3, 'Cfn::Parameter');
  is($param3->Default, '40', "The attribute 'Param3' has a property 'Default'");
}
 
done_testing; 

