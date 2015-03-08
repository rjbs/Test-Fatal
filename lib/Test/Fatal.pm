use strict;
use warnings;
package Test::Fatal;
# ABSTRACT: incredibly simple helpers for testing code with exceptions

=head1 SYNOPSIS

  use Test::More;
  use Test::Fatal;

  use System::Under::Test qw(might_die);

  is(
    exception { might_die; },
    undef,
    "the code lived",
  );

  like(
    exception { might_die; },
    qr/turns out it died/,
    "the code died as expected",
  );

  isa_ok(
    exception { might_die; },
    'Exception::Whatever',
    'the thrown exception',
  );

=head1 DESCRIPTION

Test::Fatal is an alternative to the popular L<Test::Exception>.  It does much
less, but should allow greater flexibility in testing exception-throwing code
with about the same amount of typing.

It exports one routine by default: C<exception>.

NOTE: C<exception> intentionally does not manipulate the call stack.
User-written test functions that use C<exception> must be careful to avoid
false positives if exceptions use stack traces that show arguments.  For a more
magical approach involving globally overriding C<caller>, see
L<Test::Exception>.

=cut

use Carp ();
use Try::Tiny 0.07;

use Exporter 5.57 'import';

our @EXPORT    = qw(exception);
our @EXPORT_OK = qw(exception success dies_ok lives_ok);

=func exception

  my $exception = exception { ... };

C<exception> takes a bare block of code and returns the exception thrown by
that block.  If no exception was thrown, it returns undef.

B<Achtung!>  If the block results in a I<false> exception, such as 0 or the
empty string, Test::Fatal itself will die.  Since either of these cases
indicates a serious problem with the system under testing, this behavior is
considered a I<feature>.  If you must test for these conditions, you should use
L<Try::Tiny>'s try/catch mechanism.  (Try::Tiny is the underlying exception
handling system of Test::Fatal.)

Note that there is no TAP assert being performed.  In other words, no "ok" or
"not ok" line is emitted.  It's up to you to use the rest of C<exception> in an
existing test like C<ok>, C<isa_ok>, C<is>, et cetera.  Or you may wish to use
the C<dies_ok> and C<lives_ok> wrappers, which do provide TAP output.

C<exception> does I<not> alter the stack presented to the called block, meaning
that if the exception returned has a stack trace, it will include some frames
between the code calling C<exception> and the thing throwing the exception.
This is considered a I<feature> because it avoids the occasionally twitchy
C<Sub::Uplevel> mechanism.

B<Achtung!>  This is not a great idea:

  sub exception_like(&$;$) {
      my ($code, $pattern, $name) = @_;
      like( &exception($code), $pattern, $name );
  }

  exception_like(sub { }, qr/foo/, 'foo appears in the exception');

If the code in the C<...> is going to throw a stack trace with the arguments to
each subroutine in its call stack (for example via C<Carp::confess>,
the test name, "foo appears in the exception" will itself be matched by the
regex.  Instead, write this:

  like( exception { ... }, qr/foo/, 'foo appears in the exception' );

If you really want a test function that passes the test name, wrap the
arguments in an array reference to hide the literal text from a stack trace:

  sub exception_like(&$) {
      my ($code, $args) = @_;
      my ($pattern, $name) = @$args;
      like( &exception($code), $pattern, $name );
  }

  exception_like(sub { }, [ qr/foo/, 'foo appears in the exception' ] );

B<Achtung>: One final bad idea:

  isnt( exception { ... }, undef, "my code died!");

It's true that this tests that your code died, but you should really test that
it died I<for the right reason>.  For example, if you make an unrelated mistake
in the block, like using the wrong dereference, your test will pass even though
the code to be tested isn't really run at all.  If you're expecting an
inspectable exception with an identifier or class, test that.  If you're
expecting a string exception, consider using C<like>.

=cut

our ($REAL_TBL, $REAL_CALCULATED_TBL) = (1, 1);

sub exception (&) {
  my $code = shift;

  return try {
    my $incremented = $Test::Builder::Level - $REAL_CALCULATED_TBL;
    local $Test::Builder::Level = $REAL_CALCULATED_TBL;
    if ($incremented) {
        # each call to exception adds 5 stack frames
        $Test::Builder::Level += 5;
        for my $i (1..$incremented) {
            # -2 because we want to see it from the perspective of the call to
            # is() within the call to $code->()
            my $caller = caller($Test::Builder::Level - 2);
            if ($caller eq __PACKAGE__) {
                # each call to exception adds 5 stack frames
                $Test::Builder::Level = $Test::Builder::Level + 5;
            }
            else {
                $Test::Builder::Level = $Test::Builder::Level + 1;
            }
        }
    }

    local $REAL_CALCULATED_TBL = $Test::Builder::Level;
    $code->();
    return undef;
  } catch {
    return $_ if $_;

    my $problem = defined $_ ? 'false' : 'undef';
    Carp::confess("$problem exception caught by Test::Fatal::exception");
  };
}

=func success

  try {
    should_live;
  } catch {
    fail("boo, we died");
  } success {
    pass("hooray, we lived");
  };

C<success>, exported only by request, is a L<Try::Tiny> helper with semantics
identical to L<C<finally>|Try::Tiny/finally>, but the body of the block will
only be run if the C<try> block ran without error.

Although almost any needed exception tests can be performed with C<exception>,
success blocks may sometimes help organize complex testing.

=cut

sub success (&;@) {
  my $code = shift;
  return finally( sub {
    return if @_; # <-- only run on success
    $code->();
  }, @_ );
}

=func dies_ok

=func lives_ok

Exported only by request, these two functions run a given block of code, and
provide TAP output indicating if it did, or did not throw an exception. 
These provide an easy upgrade path for replacing existing unit tests based on
C<Test::Exception>.

RJBS does not suggest using this except as a convenience while porting tests to
use Test::Fatal's C<exception> routine.

  use Test::More tests => 2;
  use Test::Fatal qw(dies_ok lives_ok);

  dies_ok { die "I failed" } 'code that fails';

  lives_ok { return "I'm still alive" } 'code that does not fail';

=cut

my $Tester;

# Signature should match that of Test::Exception
sub dies_ok (&;$) {
  my $code = shift;
  my $name = shift;

  require Test::Builder;
  $Tester ||= Test::Builder->new;

  my $ok = $Tester->ok( exception( \&$code ), $name );
  $ok or $Tester->diag( "expected an exception but none was raised" );
  return $ok;
}

sub lives_ok (&;$) {
  my $code = shift;
  my $name = shift;

  require Test::Builder;
  $Tester ||= Test::Builder->new;

  my $ok = $Tester->ok( !exception( \&$code ), $name );
  $ok or $Tester->diag( "expected return but an exception was raised" );
  return $ok;
}

1;
