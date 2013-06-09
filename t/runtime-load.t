use strict;
use warnings;
use Test::More tests => 3;
use Module::Load 'load';
use Try::Tiny;

load 'Test::Fatal', 'exception';

my $e;

try { $e = exception { die 'die 0 was not caught' }; };
like  $e, qr/die \d was not caught/, 'exception 0 caught';

try { $e = Test::Fatal::exception { die 'die 1 was not caught' }; };
like  $e, qr/die \d was not caught/, 'exception 1 caught';

require Test::Fatal;
Test::Fatal->import( 'exception' );

try { $e =  exception { die 'die 2 was not caught' }; };
like  $e, qr/die \d was not caught/, 'exception 2 caught';
