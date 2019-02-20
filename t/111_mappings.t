#!/usr/bin/env perl

use strict;
use warnings;
use Data::Printer;
use Test::More;

package TestClass {
  use CloudFormation::DSL;

  mapping Map1 => {
    key1 => 'value1',
  };

  mapping Map2 => {
    key2 => 'value2',
  };

}

my $obj = TestClass->new;

isa_ok($obj->Mapping('Map1'), 'Cfn::Mapping');

my $struct = $obj->as_hashref;

cmp_ok($struct->{Mappings}{Map1}{key1}, 'eq', 'value1', 'Got a value for a key on Map1');
cmp_ok($struct->{Mappings}{Map2}{key2}, 'eq', 'value2', 'Got a value for a key on Map2');

eval {
  package TestClass2 {
    use CloudFormation::DSL;
  
    mapping Map1 => {
      key1 => 'value1',
    };
  
    mapping Map1 => {
      key2 => 'value2',
    }; 
  }
};
like($@, qr/Redeclared/, 'Stack with a duplicate mapping throws');


eval {
  package TestClass3 {
    use CloudFormation::DSL;
  
    mapping Map1 => {
      key1 => 'value1',
    };
  
    resource Map1 => 'AWS::IAM::User', {}; 
  }
};
like($@, qr/Redeclared/, 'Stack with a duplicate mapping throws');

done_testing;
