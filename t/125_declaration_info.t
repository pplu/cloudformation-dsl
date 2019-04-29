#!/usr/bin/env perl

use strict;
use warnings; 
use Test::More;
use Test::Exception;

package AttachmentResolver {
  use Moose;
  with 'CloudFormation::DSL::AttachmentResolver';
  sub resolve { return 'STUB' }
}

package TestClass {
  use CloudFormation::DSL;

  resource R1 => 'AWS::IAM::User', {
    Path => '/'
  };

  parameter P1 => 'String', {};

  output O1 => Ref('R1');

  attachment A1 => 'AWS::EC2::Image::Id', {
    AttachParam1 => 'ip/address',
    -AttachParam2 => 'ip2/address',
  };

  condition C1 => "1";

  mapping Map1 => {
    m1 => 'm1value',
  };

  metadata M1 => 'M1Value';

  stack_version 42;

  transform 'ATransform';
}

{
  my $p = TestClass->new(attachment_resolver => AttachmentResolver->new);
  is_deeply(
    $p->declaration_info('R1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 17,
      'context' => 'resource declaration',
      'package' => 'TestClass'
    }
  );
  is_deeply(
    $p->declaration_info('P1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 21,
      'context' => 'parameter declaration',
      'package' => 'TestClass'
    }
  );
  is_deeply(
    $p->declaration_info('O1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 23,
      'context' => 'output declaration',
      'package' => 'TestClass'
    }
  );
  is_deeply(
    $p->declaration_info('A1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 25,
      'context' => 'attachment declaration',
      'package' => 'TestClass'
    }
  );
  is_deeply(
    $p->declaration_info('C1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 30,
      'context' => 'condition declaration',
      'package' => 'TestClass'
    }
  );
  is_deeply(
    $p->declaration_info('Map1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 32,
      'context' => 'mapping declaration',
      'package' => 'TestClass'
    }
  );
  is_deeply(
    $p->declaration_info('M1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 36,
      'context' => 'metadata declaration',
      'package' => 'TestClass'
    }
  );
  is_deeply(
    $p->declaration_info('StackVersion'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 38,
      'context' => 'stack_version declaration',
      'package' => 'TestClass'
    }
  );
}

package TestSubClass {
  use CloudFormation::DSL;
  extends 'TestClass';

  resource R2 => 'AWS::IAM::User', {
    Path => '/'
  };

  resource '+R1' => 'AWS::IAM::User', {
    '+Path' => 'XXX',
  };
}

{
  my $p = TestSubClass->new(attachment_resolver => AttachmentResolver->new);
  is_deeply(
    $p->declaration_info('R2'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 131,
      'context' => 'resource declaration',
      'package' => 'TestSubClass'
    }
  );
  is_deeply(
    $p->declaration_info('R1'),
    {
      'type' => 'DSL',
      'file' => 't/125_declaration_info.t',
      'line' => 135,
      'context' => 'resource declaration',
      'package' => 'TestSubClass'
    }
  );
}

done_testing; 

