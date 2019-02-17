requires 'Moose';
requires 'MooseX::Getopt';
requires 'Cfn';
requires 'Sort::Topological';
requires 'Regexp::Common';
requires 'Hash::Merge';
requires 'DateTime::Format::Strptime';
requires 'LWP::Simple';
requires 'JSON::MaybeXS';

on test => sub {
  requires 'Test::More';
  requires 'Test::Exception';
  requires 'Data::Printer';
  requires 'Test::Trap';
};
