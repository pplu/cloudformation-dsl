requires 'Moose';
requires 'Cfn', '>= 0.02';
requires 'Sort::Topological';
requires 'Regexp::Common';
requires 'Hash::Merge';
requires 'DateTime::Format::Strptime';
requires 'LWP::Simple';
requires 'JSON::MaybeXS';
requires 'Hash::AsObject';
requires 'true';

on test => sub {
  requires 'Test::More';
  requires 'Test::Exception';
  requires 'Data::Printer';
  requires 'Test::Trap';
  requires 'Test::File::Contents';
  requires 'Test::Pod';
};
