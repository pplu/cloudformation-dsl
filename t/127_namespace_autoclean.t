use strict;
use warnings;
use Test::More;

{
    package TestClass;
    sub bar { }
    use CloudFormation::DSL;
    sub moo { }
    BEGIN { *kooh = *kooh = do { package Moose; sub { }; }; }
    BEGIN { *affe = *affe = sub { }; }
}
 
ok( TestClass->can('bar'), 'TestClass can bar - standard method');
ok( TestClass->can('moo'), 'TestClass can moo - standard method');
ok(!TestClass->can('kooh'), 'TestClass cannot kooh - anon sub from another package assigned to glob');
ok( TestClass->can('affe'), 'TestClass can affe - anon sub assigned to glob in package');
 
done_testing();

