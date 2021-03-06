#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

throws_ok {
  package TestDuplicate {
    use CloudFormation::DSL;

    attachment att1 => 'Test', {
      att1 => 'value'
    };
  }
} qr/Redeclared/, "Can't create args with two equal parameter names";

package TestAttach {
  use CloudFormation::DSL;

  attachment Attachment => 'Test', {
    IAMPath => 'iam_path',
    -IAMPathStatic => 'iam_path',
  };

  resource R1 => 'AWS::IAM::User', {
    Path => Ref('IAMPath'),
  };
  resource R2 => 'AWS::IAM::User', {
    Path => Parameter('IAMPathStatic'),
  };
}

{
  throws_ok(sub { TestAttach->new },
	    qr/Can\'t resolve attachments without an attachment_resolver/,
	    'attachments aren\'t resolved without an attachment resolver',
  );
}

package TestAttachmentResolver {
  use Moose;
  with 'CloudFormation::DSL::AttachmentResolver';

  sub resolve {
    my ($self, $name, $type, $lookup_key) = @_;

    return '/iampath/path1' if ($type eq 'Test' and $lookup_key eq 'iam_path');
    die "Can't resolve attachment for $name of type $type for lookup_key $lookup_key";
  } 
}

{
  my $arch = TestAttach->new(params => { Attachment => 'Stack1' }, attachment_resolver => TestAttachmentResolver->new);
  isa_ok($arch->IAMPath, 'Cfn::Parameter');
  cmp_ok($arch->params->IAMPath, 'eq', '/iampath/path1', 'Got the appropiate value returned from the IAMPath parameter');

  isa_ok($arch->IAMPathStatic, 'Cfn::Parameter');
  cmp_ok($arch->params->IAMPathStatic, 'eq', '/iampath/path1', 'Got the appropiate value returned from the StaticIAMPath parameter');

  cmp_ok($arch->as_hashref->{Resources}{R2}{Properties}{Path}, 'eq', '/iampath/path1');
}

{
  # Testing if we can overwrite attachment values from params
  my $arch = TestAttach->new(params => { Attachment => 'Stack1', IAMPath => 'X', IAMPathStatic => 'Y' }, attachment_resolver => TestAttachmentResolver->new);
  isa_ok($arch->IAMPath, 'Cfn::Parameter');
  cmp_ok($arch->params->IAMPath, 'eq', 'X', 'Got the appropiate value returned from the IAMPath parameter');

  isa_ok($arch->IAMPathStatic, 'Cfn::Parameter');
  cmp_ok($arch->params->IAMPathStatic, 'eq', 'Y', 'Got the appropiate value returned from the StaticIAMPath parameter');

  cmp_ok($arch->as_hashref->{Resources}{R2}{Properties}{Path}, 'eq', 'Y');
}

throws_ok {
  package Duplicateattachmentprovides1 {
    use CloudFormation::DSL;
    attachment Attachment => 'Test', {
        att1  => 'value',
      '-att1' => 'value',
    };
  }
} qr/Redeclared/, "Can't create two provides with same name";

throws_ok {
  package Duplicateattachmentprovides2 {
    use CloudFormation::DSL;
    attachment Attachment => 'Test', {
        att1  => 'value',
    };
    attachment Attachment2 => 'Test', {
        att1  => 'value',
    };
  }
} qr/Redeclared/, "Can't create two provides with same name on different attachments";

throws_ok {
  package Duplicateattachmentprovides3 {
    use CloudFormation::DSL;
    attachment Attachment => 'Test', {
        att1  => 'value',
    };
    attachment Attachment => 'Test', {
        att2  => 'value',
    };
  }
} qr/Redeclared/, "Can't create two provides with same name on different attachments";


package TestAttachWithDefault {
  use CloudFormation::DSL;

  attachment Attachment => 'Test', {
    Att => 'iam_path',
    -AttStatic => 'iam_path',
  }, {
    Default => 'SomeAttachedStack'
  };
}

{
  my $t = TestAttachWithDefault->new(attachment_resolver => TestAttachmentResolver->new, params => {});
  cmp_ok($t->params->Attachment, 'eq', 'SomeAttachedStack', 'Can specify a default value for the attachment');
  cmp_ok($t->params->Att, 'eq', '/iampath/path1', 'The provides is resolved too...');
  cmp_ok($t->params->AttStatic, 'eq', '/iampath/path1', 'The provides is resolved too...');
}

done_testing;
