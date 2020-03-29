use Test::More;
use Test::Pod;
use Test::File::Contents;

pod_file_ok ('lib/CloudFormation/DSL.pm', 'CloudFormation/DSL.pm contains valid POD');
file_contents_unlike 'README.md', qr/^# POD ERRORS$/m, "README file doesn't contains POD errors";

done_testing();
