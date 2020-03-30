use Test::More;
use AWS;

foreach my $thing ( keys %AWS:: ) {
  my $sub = *{ "AWS::$thing" };
  if ( defined &$sub ) {    
    is_deeply ( &$sub , { 'Ref' => "AWS::$thing" }, "AWS::$thing" );
  }
}


done_testing();