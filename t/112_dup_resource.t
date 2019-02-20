#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

#
# This test is designed to verify that the shortcut "resource" assigns extra information (the
# fourth parameter) correctly to resources
#

dies_ok {
  package TestClass {
    use CloudFormation::DSL;
  
    resource User => 'AWS::IAM::User', {
      Path => '/',
    };
  
    resource User => 'AWS::IAM::User', {
      Path => '/2/',
    };
  } 
} 'Repeated resource should not be permitted';

done_testing; 
