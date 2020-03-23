use strict;
use warnings;
use Test::More;
use Test::Exception;

package TestClass {
  use CloudFormation::DSL;
}

{
    my $obj = TestClass->new();    
    throws_ok( sub { $obj->meta()->add_attribute( '__test_attribute', is=>'ro') }, qr/The 'add_attribute' method cannot be called on an immutable instance/,
        'class is inmutable');
}

done_testing();