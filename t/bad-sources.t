use strict;
use warnings;
use Test::More;
use Dotenv;

# let's do modern things with ancient stuff
format FOO =
@<<<<<<   @||||||   @>>>>>>
.

my @bad = (
    undef,
    bless( {}, 'Klonk' ),    # object
    sub { },                 # code ref
    qr/klonk/,               # regexp
    \\"foo",                 # reference
    *FOO{FORMAT},            # format
);

for my $source (@bad) {
    my $kv;
    ok(
        !eval { $kv = Dotenv->parse($source); 1; },
        ( $source // 'undef' ) . ' is not a valid source'
    );
    like(
        $@,
        defined $source
        ? qr/^Don't know how to read from '\Q$source\E' /
        : qr/^Can't handle an uninitialized value /,
        '... got expected error message'
    );
    is( $kv, undef, '... and no data' );
}

done_testing;
