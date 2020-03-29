#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Trap;
use CloudFormation::DSL;

is_deeply(
  Fn::Join('-', 'Value1', 'Value2'),
  { 'Fn::Join' => [ '-', [ 'Value1', 'Value2' ] ] },
  'Join used as function'
);
is_deeply(
  Fn::Base64('This is a base64 string'),
  { 'Fn::Base64' => 'This is a base64 string' },
  'Base64 used as Function'
);

is_deeply(
  Fn::Cidr('1.1.1.1', 2, 16),
  { 'Fn::Cidr' => [ '1.1.1.1', 2, 16 ] }
);

is_deeply(
  Fn::Cidr('1.1.1.1', 2),
  { 'Fn::Cidr' => [ '1.1.1.1', 2 ] }
);

is_deeply(
  Fn::And( 'val1' , 'val2' ),
  { 'Fn::And' => [ 'val1', 'val2' ] },
  'And used as Function'
);

done_testing;
