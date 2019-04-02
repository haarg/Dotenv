package Dotenv;

use strict;
use warnings;

use Carp         ();
use Scalar::Util ();
use Dotenv::File;

our @CARP_NOT = qw(Dotenv::File);

sub import {
    my ( $package, @args ) = @_;
    if (@args) {
        my $action = shift @args;
        if ( $action eq '-load' ) {
            $package->load(@args);
        }
        else {
            Carp::croak "Unknown action $action";
        }
    }
}

sub parse {
    my ( $package, @sources ) = @_;
    @sources = ('.env') if !@sources;

    my %env;
    for my $source (@sources) {
        Carp::croak "Can't handle an uninitialized value"
          if !defined $source;

        my %kv;
        if ( ref $source eq 'HASH' ) {    # bare hash ref
            %kv = %$source;
        }
        else {
            if ( ref $source eq 'ARRAY' ) { # bare array ref
                $source = \join("\n", @$source);
            }
            elsif ( !ref $source || ref $source eq 'SCALAR' || Scalar::Util::openhandle($source) ) {
                # already ok
            }
            elsif ( eval { $source->can('getline') } ) {
                local $/;
                $source = \scalar $source->getline;
            }
            else {
                Carp::croak "Don't know how to read from '$source'";
            }
            %kv = Dotenv::File->read($source)->as_hash;
        }

        # don't overwrite anything that already exists
        %env = ( %kv, %env );
    }

    return \%env;
}

sub load {
    my ( $package, @sources ) = @_;
    @sources = ('.env') if !@sources;
    %ENV = %{ $package->parse( \%ENV, @sources ) };
    return \%ENV;
}

'.env';

__END__

=pod

=head1 NAME

Dotenv - Support for C<dotenv> in Perl

=head1 SYNOPSIS

    # basic operation
    use Dotenv;      # exports nothing
    Dotenv->load;    # merge the content of .env in %ENV

    # do it all in one line
    use Dotenv -load;

    # the source for environment variables can be a file, a filehandle,
    # a hash reference, an array reference and several other things
    # the sources are loaded in %ENV without modifying existing values
    Dotenv->load(@sources);

    # sources can also be loaded via import
    use Dotenv -load => 'local.env';

    # add some local stuff to %ENV (from a non-file source)
    # (.env is the default only if there are no arguments)
    Dotenv->load( \%my_env );

    # return a reference to a hash populated with the key/value pairs
    # read in the file, but do not set %ENV
    my $env = Dotenv->parse('app.env');

    # dynamically add to %ENV
    local %ENV = %{ Dotenv->parse( \%ENV, 'test.env' ) };

    # order of arguments matters, so this might yield different results
    # (here, values in 'test.env' take precedence over those in %ENV)
    local %ENV = %{ Dotenv->parse( 'test.env', \%ENV ) };

=head1 DESCRIPTION

C<Dotenv> adds support for L<.env|https://12factor.net/config> to Perl.

Storing configuration in the environment separate from code comes from
The Twelve-Factor App methodology. This is done via F<.env> files, which
contains environment variable definitions akin to those one would write
for a shell script.

C<Dotenv> has only two methods, and exports nothing.

=head1 METHODS

=head2 parse

    $env = Dotenv->parse(@sources);

Parse the content of the provided sources.

Return a reference to a hash populated with the list of key/value pairs
read from the sources,

If no sources are provided, use the F<.env> file in the current working
directory as the default source.

=head2 load

    Dotenv->load(@sources);

Behaves exactly like L<parse>, and also update L<perlvar/%ENV> with the
key/value pairs obtained for the sources.

If no sources are provided, use the F<.env> file in the current working
directory as the default source.

C<load> can also be called while loading the module, with the sources
provided as a LIST (an empty list still means to use the default source):

    use Dotenv -load;

    use Dotenv -load => LIST;

=head1 THE "ENV" FORMAT

=head2 Data Format

The "env" data format is a line-based format consisting of lines of
the form:

    KEY=VALUE

Comments start at the C<#> character and go until the end of the line.
Blank lines are ignored.

The format is somewhat compatible with shell (so with a minimum of
effort, it's possible to read the environment variables use the
C<.> or C<source> shell builtins).

The significant differences are:

=over 4

=item *

support for whitespace around the C<=> sign, and trimming of whitespace,

=item *

C<\n> expansion and C<\>-escaping in double-quoted strings,

=item *

no support for C<\> line continuations,

=item *

no support for running shell commands via C<``> or C<$()>,

=item *

no variable expansion (support for that is planned).

=back

=head2 Data Sources

C<Dotenv> can read environment variables from multiple sources:

=over 4

=item *

a scalar (containing the name of a file to be read),

=item *

a reference to scalar (containing the data to be parsed),

=item *

an array reference (containing lines of data),

=item *

a glob or a filehandle (data will be read directly from it),

=item *

an object with a C<readline> method (data will be read using that method),

=back

Anything else will cause a fatal exception.

=head1 SEE ALSO

=over 4

=item *

The Twelve-Factor app methodology, L<https://12factor.net/>.

=item *

Python implentation, L<https://pypi.org/project/python-dotenv/>.

=item *

Ruby implementation, L<https://rubygems.org/gems/dotenv/>.

=item *

Node implementation, L<https://www.npmjs.com/package/dotenv>.

=back

=head1 ACKNOWLEDGEMENTS

The original version of this module was created as part of my work
for L<BOOKING.COM|http://www.booking.com/>, which authorized its
publication/distribution under the same terms as Perl itself.

=head1 AUTHORS

Philippe Bruhat (BooK) <book@cpan.org>

Graham Knop (haarg) <haarg@haarg.org>

=head2 CONTRIBUTORS

None so far.

=head1 COPYRIGHT

Copyright (c) 2019 the Dotenv L</AUTHORS> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
