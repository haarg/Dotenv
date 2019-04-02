use strict;
use warnings;
use Test::More;
use Dotenv;

for my $env ( glob './t/env/*.env' ) {
    ( my $pl = $env ) =~ s/\.env\z/.pl/;
    die "missing $pl"
        unless -e $pl;
    my $expected = do $pl or die "error loading $pl: " .($@||$!);

    # parse
    my $got = Dotenv->parse($env);
    is_deeply( $got, $expected, "$env (parse)" );
}

done_testing;
