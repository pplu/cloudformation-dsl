#!/usr/bin/env perl
use strict;
use warnings; 
use feature 'say';

use Moose::Util 'find_meta';
use Test::More;
use Test::Exception;

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
  
  output Output1 => Ref('X1');
  output Output2 => Ref('X2');
  
  1;
}

my $meta = find_meta('TestClass');


my $attr_count = scalar grep { $_ eq 'Param1' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'Param1'");

{
  my $param1 = $meta->get_attribute('Param1'); 
  isa_ok($param1->type_constraint->class, 'Cfn::Parameter', "'The attribute 'Param1' isa 'Cfn::Parameter'");
  
  ok($param1->does('Parameter'), "The attribute 'Param1' has the trait 'CCfnX::Meta::Attribute::Trait::Parameter'");
 
  is($param1->Type, 'String', "The attribute 'Param1' has a property 'Type' (set by 'parameter' function of 'CCfnX::Shortcuts')");
  
  is($param1->Default, 'this is the default value', "The attribute 'Param1' has a property 'Default'");
  
  is($param1->MaxLength, 30, "The attribute 'Param1' has a property 'MaxLength'");
  
  is($param1->Description, 'Param1 Description', "The attribute 'Param1' has a property 'Description'");
}

$attr_count = scalar grep { $_ eq 'Param2' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'Param2'");

my $param2 = $meta->get_attribute('Param2'); 
ok($param2->does('StackParameter'), "The attribute 'Param2' has the trait 'CCfnX::Meta::Attribute::Trait::StackParameter");

$attr_count = scalar grep { $_ eq 'Param3' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'Param3'");

my $param3 = $meta->get_attribute('Param3');
ok($param3->Default, "The attribute 'Param3' has a Default set");

$attr_count = scalar grep { $_ eq 'Attach1' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'Attach1'");

my $attach1 = $meta->get_attribute('Attach1');
ok($attach1->does('Attachable'), "The attribute 'Attach1' has the trait 'CCfnX::Meta::Attribute::Trait::Attachable");

$attr_count = scalar grep { $_ eq 'AttachParam1' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'AttachParam1'");

my $attachparam1 = $meta->get_attribute('AttachParam1');
ok($attachparam1->does('StackParameter'), "The attribute 'AttachParam1' has the trait 'CCfnX::Meta::Attribute::Trait::StackParameter");

$attr_count = scalar grep { $_ eq 'AttachParam2' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'AttachParam2'");

$attr_count = scalar grep { $_ eq 'Output1' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'Output1'");

$attr_count = scalar grep { $_ eq 'Output2' } $meta->get_attribute_list;
is(1, $attr_count, "TestClass has an attribute 'Output2'");

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
    Description => 'Param1 Description',
  };
}

package TestClass4 {
  use CloudFormation::DSL;
  extends 'TestClass4Base';

  parameter '+Param2' => 'Number', {
    MaxLength   => 35,
    Default     => 'this is the default value',
    Description => 'Param1 Description',
  };

  parameter Param3 => 'String', {
    Default => 40,
  };
}

{
  my $c1 = TestClass4Base->new;
  cmp_ok($c1->params->Param1, 'eq', 'param1 default');
  ok(not defined $c1->Parameter('Param1'));
  cmp_ok($c1->params->Param2, 'eq', 'param2 default');
  ok(not defined $c1->Parameter('Param2'));
 
  my $c2 = TestClass4->new;
  cmp_ok($c2->params->Param1, 'eq', 'param1 default');
  ok(not defined $c1->Parameter('Param1'));
  cmp_ok($c2->params->Param2, 'eq', 'this is the default value');
  ok(not defined $c1->Parameter('Param2'));
  cmp_ok($c2->params->Param3, '==', 40);
  ok(not defined $c1->Parameter('Param3'));
}
 
done_testing; 

