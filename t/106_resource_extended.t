#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

#
# This test is designed to verify that the shortcut "resource" assigns extra information (the
# fourth parameter) correctly to resources
#

package TestClass {
  use CloudFormation::DSL;

  resource User => 'AWS::IAM::User', {
    Path => '/',
  }, {
    Metadata => { 'is' => 'Metadata' },
    DeletionPolicy => 'Retain',
  };
}

my $obj = TestClass->new;

cmp_ok($obj->Resource('User')->Properties->Path->as_hashref, 'eq', '/', 'Path is accessible');
is_deeply($obj->Resource('User')->Metadata->as_hashref, { is => 'Metadata' }, 'Metadata is correct');
cmp_ok($obj->Resource('User')->DeletionPolicy, 'eq', 'Retain', 'DeletionPolicy is correct');


package TestClass2 {
  use CloudFormation::DSL;

  resource User => 'AWS::IAM::User', {
    Path => '/',
  }, {
    Metadata => { 'is' => 'Metadata' },
    DeletionPolicy => 'Retain',
    UpdatePolicy => {
      AutoScalingReplacingUpdate => { WillReplace => Parameter('my_param') },
      UseOnlineResharding => 'true',
    },
  };
}

$obj = TestClass2->new;
cmp_ok($obj->Resource('User')->Properties->Path->as_hashref, 'eq', '/', 'Path is accessible');
is_deeply($obj->Resource('User')->Metadata->as_hashref, { is => 'Metadata' }, 'Metadata is correct');
cmp_ok($obj->Resource('User')->DeletionPolicy, 'eq', 'Retain', 'DeletionPolicy is correct');
my $hashref = $obj->as_hashref;
is_deeply(
  $hashref->{Resources}->{User}->{UpdatePolicy},
  {'AutoScalingReplacingUpdate' => {'WillReplace' => 'true'}, UseOnlineResharding => 'true' },
  'UpdatePolicy is correct'
);
cmp_ok(
  $hashref->{Resources}->{User}->{UpdatePolicy}->{AutoScalingReplacingUpdate}->{WillReplace},
  'eq',
  'true',
  'Parameter correctly resolved in UpdatePolicy'
);

package TestClass3 {
  use CloudFormation::DSL;

  resource User => 'AWS::IAM::User', {
    Path => '/',
  }, {
    UpdatePolicy => {
       AutoScalingRollingUpdate => { 
         SuspendProcesses => [ 'Terminate', 'ReplaceUnhealthy' ],
       }
    },
  };
}

$obj = TestClass3->new;
cmp_ok($obj->Resource('User')->Properties->Path->as_hashref, 'eq', '/', 'Path is accessible');
$hashref = $obj->as_hashref;
is_deeply(
  $hashref->{Resources}->{User}->{UpdatePolicy},
  {'AutoScalingRollingUpdate' => {
      'SuspendProcesses' => [ 'Terminate', 'ReplaceUnhealthy' ]
    }
  },
  'UpdatePolicy->AutoScalingRollingUpdate is correctly validated'
);
cmp_ok(
  $hashref->{Resources}->{User}->{UpdatePolicy}->{AutoScalingRollingUpdate}->{SuspendProcesses}->[0],
  'eq',
  'Terminate',
  'SuspendPolicy inside AutoScalingRollingUpdate is ok'
);

done_testing; 
