use Test::More;
use AWS;

my @pseudoparams = qw/AccountId Partition NotificationARNs StackName StackId Region URLSuffix NoValue/;

foreach my $thing ( @pseudoparams ) {
  my $sub = *{ "AWS::$thing" };
  is_deeply ( &$sub , { 'Ref' => "AWS::$thing" }, "AWS::$thing" );
}


done_testing();