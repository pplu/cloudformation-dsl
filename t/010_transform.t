#!/usr/bin/env perl

use strict;
use warnings;

use Cfn;
use Test::More;

{

  package GlobalTransform {
    use CloudFormation::DSL;
    use CCfnX::CommonArgs;

    has params => ( is => 'ro', isa => 'CCfnX::CommonArgs', default => sub { CCfnX::CommonArgs->new( {
            name    => 'GlobalTransform',
            region  => 'eu-west-1',
            account => 'test',
    } ) } );

    transform 'MyTransform';
  }

  my $cfn  = GlobalTransform->new();
  my $hash = $cfn->as_hashref;

  is_deeply( $hash->{Transform}, ['MyTransform'] );
}

done_testing;
