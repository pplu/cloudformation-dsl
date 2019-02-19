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
} qr/already exists/, "Can't create args with two equal parameter names";

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
  my $arch = TestAttach->new();
  throws_ok(sub { $arch->IAMPath->Value->($arch), 'eq', '/iampath/path1' },
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
  cmp_ok($arch->IAMPath->Value->($arch), 'eq', '/iampath/path1', 'Got the appropiate value returned from the IAMPath parameter');

use Data::Dumper;
print Dumper($arch->as_hashref);
  #cmp_ok($params->Att->Value, 'eq', 'Manual Value', 'Can specify an argument from an attachment without specifying the attachment');
  cmp_ok($arch->as_hashref->{Resources}{R2}{Properties}{Path}, 'eq', '/iampath/path1');
}



throws_ok {
  package TestArgsWithDefault {
    use CloudFormation::DSL;
    attachment att1 => 'Test', {
      att1 => 'value',
    };
  }
} qr/already exists/, "Can't create args with two equal parameter names";


package TestAttachWithDefault {
  use CloudFormation::DSL;

  attachment Attachment => 'Test', {
    Att => 'value' 
  }, {
    Default => 'SomeAttachedStack'
  };
}

{
  my $t = TestAttachWithDefault->new();
  cmp_ok($t->Attachment, 'eq', 'SomeAttachedStack', 'Can specify a default value for the attachment');
}

done_testing;
