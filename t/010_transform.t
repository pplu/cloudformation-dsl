#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{

  package GlobalTransform {
    use CloudFormation::DSL;

    transform 'MyTransform';
  }

  my $cfn  = GlobalTransform->new();
  my $hash = $cfn->as_hashref;

  is_deeply( $hash->{Transform}, ['MyTransform'] );
}

done_testing;
