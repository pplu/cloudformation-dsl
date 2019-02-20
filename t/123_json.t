#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use CloudFormation::DSL qw/Json/;

is_deeply(
  Json('{"a":"json document"}'),
  { a => 'json document' },
  'Text to JSON'
);

throws_ok(sub {
  Json('this is not JSON'),
}, qr/Error decoding Json/);

done_testing;
