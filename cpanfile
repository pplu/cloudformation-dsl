requires 'Moose';
requires 'MooseX::Getopt';
requires 'Cfn';
requires 'Sort::Topological';
requires 'Regexp::Common';
requires 'Hash::Merge';
requires 'JSON::MaybeXS';
requires 'Hash::AsObject';

on test => sub {
  requires 'Test::More';
  requires 'Test::Exception';
  requires 'Data::Printer';
  requires 'Test::Trap';
};
