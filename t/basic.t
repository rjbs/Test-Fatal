use strict;
use warnings;
use Test::More tests => 5;
use Test::Fatal qw(exception success);
use Try::Tiny 0.07;

like(
  exception { die "foo bar" },
  qr{foo bar},
  "foo bar is like foo bar",
);

ok(
  ! exception { 1 },
  "no fatality means no exception",
);

try {
  die "die";
} catch {
  pass("we die on demand");
} success {
  fail("this should never be emitted");
};

try {
  # die "die";
} catch {
  fail("we did not demand to die");
} success {
  pass("a success block runs, passing");
};

# TODO: test for fatality of undef exception?

{
  package BreakException;
  sub DESTROY { eval { my $x = 'o no'; } }
}

like(
  exception { exception {
    my $blackguard = bless {}, 'BreakException';
    die "real exception";
  } },
  qr{false exception},
  "we throw a new exception if the exception is false",
);
