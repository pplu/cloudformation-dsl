#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

package TestClass {
  use CloudFormation::DSL;

  condition CreateProdResources => Fn::Equals(Ref('EnvType'), "prod");

  resource R1 => 'AWS::IAM::User', {}, { Condition => 'CreateProdResources' };
}

my $obj = TestClass->new;
my $struct = $obj->as_hashref;

is_deeply($struct->{ Resources }->{ R1 }, { Type => 'AWS::IAM::User', Condition => 'CreateProdResources', Properties => {} });
is_deeply($struct->{ Conditions }->{ CreateProdResources }, {
                                                       'Fn::Equals' => [
                                                                         {
                                                                           'Ref' => 'EnvType'
                                                                         },
                                                                         'prod'
                                                                       ]
                                                     });
done_testing;
