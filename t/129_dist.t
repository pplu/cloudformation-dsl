use Test::More;
use Test::File::Contents;

file_contents_unlike 'README.md', qr/^# POD ERRORS$/m, "README file doesn't contains POD errors";

done_testing();
