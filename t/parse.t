use strict;
use warnings;
use Test::More;
use Dotenv::File;

if (@ARGV && $ARGV[0] eq '--dump') {
    require Data::Dumper;
    for my $env ( glob './t/env/*.env' ) {
        ( my $pl = $env ) =~ s/\.env\z/.pl/;
        my $got = Dotenv::File->read($env)->as_hashref;
        no warnings 'once';
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::Sortkeys = 1;
        local $Data::Dumper::Indent = 1;
        local $Data::Dumper::Trailingcomma = 1;
        local $Data::Dumper::Useqq = 1;
        open my $fh, '>', $pl
            or die "unable to open $pl: $!";
        print $fh Data::Dumper::Dumper($got);
        close $fh;
    }
}

for my $env ( glob './t/env/*.env' ) {
    ( my $pl = $env ) =~ s/\.env\z/.pl/;
    die "missing $pl"
        unless -e $pl;
    my $expected = do $pl or die "error loading $pl: " .($@||$!);

    # parse
    my $got = eval { Dotenv::File->read($env)->as_hashref };
    my $e = $@ || undef;
    is $e, undef;
    is_deeply( $got, $expected, "parsed $env correctly" );
}

done_testing;
