use strict;
use warnings;
use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use lib "$Bin/126_true";

BEGIN { 
    use_ok('TestTrue');
    use_ok('TestTrueCurly');
    use_ok('TestNonTrue');
    use_ok('TestNonTrueCurly');
}

done_testing();
