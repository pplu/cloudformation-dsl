#!/usr/bin/env perl

use Test::More;

use CloudFormation::DSL qw/Tag/;

is_deeply(
  Tag('TagName', 'TagValue'),
  { Key => 'TagName', Value => 'TagValue' },
  'standard Tag behaviour',
);

# AutoScaling Group tags need a PropagateAtLaunch property
# https://docs.aws.amazon.com/es_es/AWSCloudFormation/latest/UserGuide/aws-properties-as-tags.html
is_deeply(
  Tag('TagName', 'TagValue', PropagateAtLaunch => 1),
  { Key => 'TagName', Value => 'TagValue', PropagateAtLaunch => 1 },
  'pass extra keys and values to the tag'
);

done_testing;
