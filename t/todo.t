#!/usr/bin/perl

use strict;

use Test::Builder::Tester;

use Test::More;
use Test::Fatal;

if (eval { require Test::Builder::Provider; 1 }) {
    # Test::Builder has been updated recently to no longer use $Level, instead
    # it uses a system of marking subs and using intelligent stack traces. Some
    # $Level support still exists for legacy code.
    # The problem here is that Test::Builder and this module disagree on where
    # things should trace to. See #TB TODO notes below.
    plan 'skip_all' => "Newer Test::Builder makes this test irrelevent, and broken";
}
else {
    plan tests => 4;
}

{
    my $line = __LINE__ + 13;
    my $out = <<FAIL;
not ok 1 - succeeded # TODO unimplemented
#   Failed (TODO) test 'succeeded'
#   at t/todo.t line $line.
#          got: '0'
#     expected: '1'
ok 2 - no exceptions # TODO unimplemented
FAIL
    chomp($out);
    test_out($out);
    {
        local $TODO = "unimplemented";
        is(exception { is(0, 1, "succeeded") }, undef, "no exceptions");
    }
    test_test( "\$TODO works" );
}

{
    my $line = __LINE__ + 13;
    my $out = <<FAIL;
not ok 1 - succeeded # TODO unimplemented
#   Failed (TODO) test 'succeeded'
#   at t/todo.t line $line.
#          got: '0'
#     expected: '1'
ok 2 - no exceptions # TODO unimplemented
FAIL
    chomp($out);
    test_out($out);
    {
        local $TODO = "unimplemented";
        stuff_is_ok(0, 1);
    }
    test_test( "\$TODO works" );

    sub stuff_is_ok {
        my ($got, $expected) = @_;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        is(
            exception { is($got, $expected, "succeeded") }, #TB TODO: The error should trace here, to the 'is' call
            undef,
            "no exceptions"
        );
    }
}

{
    my $line = __LINE__ + 13;
    my $out = <<FAIL;
not ok 1 - succeeded # TODO unimplemented
#   Failed (TODO) test 'succeeded'
#   at t/todo.t line $line.
#          got: '0'
#     expected: '1'
ok 2 - no exceptions # TODO unimplemented
FAIL
    chomp($out);
    test_out($out);
    {
        local $TODO = "unimplemented";
        stuff_is_ok2(0, 1);
    }
    test_test( "\$TODO works" );

    sub stuff_is_ok2 {
        my ($got, $expected) = @_;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        _stuff_is_ok2(@_);
    }

    sub _stuff_is_ok2 {
        my ($got, $expected) = @_;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        is(
            exception { is($got, $expected, "succeeded") }, #TB TODO: Same
            undef,
            "no exceptions"
        );
    }
}

{
    my $line = __LINE__ + 14;
    my $out = <<FAIL;
not ok 1 - succeeded # TODO unimplemented
#   Failed (TODO) test 'succeeded'
#   at t/todo.t line $line.
#          got: '0'
#     expected: '1'
ok 2 - no exceptions # TODO unimplemented
ok 3 - level 1 # TODO unimplemented
FAIL
    chomp($out);
    test_out($out);
    {
        local $TODO = "unimplemented";
        multi_level_ok(0, 1);
    }
    test_test( "\$TODO works" );

    sub multi_level_ok {
        my ($got, $expected) = @_;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        is(
            exception { _multi_level_ok($got, $expected) },
            undef,
            "level 1"
        );
    }

    sub _multi_level_ok {
        my ($got, $expected) = @_;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        is(
            exception { is($got, $expected, "succeeded") }, #TB TODO: And again
            undef,
            "no exceptions"
        );
    }
}
