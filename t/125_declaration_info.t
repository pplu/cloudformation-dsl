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

  resource 'R1' => 'AWS::IAM::User', {
    Path => '/'
  };

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
    Default => 314,
    Description => 'Param3 description',
  };

  attachment Attach1 => 'AWS::EC2::Image::Id', {
    AttachParam1 => 'ip/address',
    -AttachParam2 => 'ip2/address',
  };
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
}
 
done_testing; 

