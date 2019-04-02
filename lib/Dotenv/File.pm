package Dotenv::File;
# vi: ts=4:sts=4:sw=4:et:
use strict;
use warnings;
use Carp qw(croak carp);
use Scalar::Util qw(openhandle blessed);

sub new {
    my $class = shift;
    my %args = @_ == 1 && ref $_[0] ? %{$_[0]} : @_;
    my $self = bless {
        strict => !!$args{strict},
        export => !!$args{export},
    }, $class;
    my $settings = $args{settings};
    my @settings
      = !defined $settings       ? ()
      : ref $settings eq 'ARRAY' ? @$settings
      : ref $settings eq 'HASH'  ? %$settings
      : croak "settings must be an array ref or a hash ref!";
    while (my ($key, $value) = splice @settings, 0, 2) {
        $self->set($key, $value);
    }
    return $self;
}

sub strict {
    if (@_ > 1) {
        return $_[0]->{strict} = $_[1];
    }
    $_[0]->{strict};
}

sub export {
    if (@_ > 1) {
        return $_[0]->{export} = $_[1];
    }
    $_[0]->{export};
}

my %dqescape = (
    "\n" => "\\n",
    (map +($_ => "\\$_"), qw( " $ ` \ ! )),
);
my %unescape = reverse %dqescape;
my ($dqmatch) = map qr/[$_]/, join '', sort keys %dqescape;

sub _escape {
    my ($self, $str) = @_;

    if (
        $str =~ /\A(.*?)([\x00\r])/s
        or $self->{strict} && $str =~ /\A(.*?)(\n)/s
    ) {
        croak sprintf q{Unquotable character %02X found after "%s"!}, ord($1), $2;
    }
    elsif ($str !~ /\W/) {
        return $str;
    }
    elsif ($str !~ /[\x00-\x1f']/) {
        return qq{'$str'};
    }
    else {
        $str =~ s{($dqmatch)}{$dqescape{$1}}g;
        return qq{"$str"};
    }
}

sub _fail {
    my ($line, $name, $ln, $want) = @_;
    my $char = 1 + pos $$line;
    my @args = ($char, $want, $$line, ( '-' x ($char-1) ) . '^');
    my $format = qq{character %d, expected %s:\n%s\n%s};
    if (defined $name) {
        unshift @args, $name;
        $format = '%s ' . $format;
    }
    if (defined $ln) {
        unshift @args, $ln;
        $format = 'line %d ' . $format;
    }
    croak sprintf "Parsing failed at $format", @args;
}

my $key_strict_re = qr{[a-zA-Z_][a-zA-Z0-9_]*};
my $key_loose_re  = qr/[\w.-]+/;

sub _reader {
    my ($read) = @_;

    my $name;

    if (ref $read eq '') {
        $name = $read;
        open my $fh, '<', $read
            or croak "Unable to read $read: $!";
        $read = $fh;
    }
    elsif ( ref $read eq 'ARRAY' ) {
        $name = 'array content';
        my @read = @$read;
        s/\n?\z/\n/ for @read;
        $read = \join('', @read);
    }

    if (ref $read eq 'SCALAR') {
        $name ||= 'scalar content';
        return $name => sub {
            $$read =~ m/\G(.*?)(?:\r\n?|\n|\z)/gc
                or return undef;
            return "$1";
        }
    }
    elsif ( openhandle($read) ) {
        $name ||= 'file handle';
        return $name => sub {
            my $line = readline $read;
            return undef
                if !defined $line;
            chomp $line;
            utf8::decode($line) unless utf8::is_utf8($line);
            return $line;
        };
    }
    elsif ( blessed($read) && eval { $read->can('getline') } ) {
        $name ||= 'object';
        return $name => sub {
            my $line = $read->getline;
            return undef
                if !defined $line;
            chomp $line;
            utf8::decode($line) unless utf8::is_utf8($line);
            return $line;
        };
    }
    else {
        croak "Don't know how to read from '$read'";
    }
}

sub read {
    my $class = shift;
    my $file = shift;

    my $self = ref $class ? $class : $class->new(@_);

    my ($name, $reader) = _reader($file);
    local $/ = "\n";

    my @lines;
    my %settings;

    my $prefix_re =
        !$self->{strict} || $self->{export} ? qr/\s*(?:export\s+)?/
                                            : qr{\s*}
    ;
    my ($key_re, $assign_re, $unescape_re) =
        $self->{strict} ? (
            $key_strict_re,
            qr{=},
            qr{["\$`\\]},
        ) : (
            $key_loose_re,
            qr/\s*=\s*/,
            qr{["\$`\\n]},
        );
    my $value_re = qr{
            '[^\x00\r\n']*'
        |
            "(?:[^\x00\r\n"\$`\\]|\\.)*"
        |
            (?:[^\x00\r\n'"\$`\\\s]|\\.)*
    }x;

    my $ln = 0;
    while (defined( my $line = $reader->() )) {
        $ln++;

        my $prefix = '';
        if ($ln == 1 and $line =~ m{\G(\x{feff})}gc) {
            $prefix .= $1;
        }
        if ($line =~ m{\G\s*(?:#|\z)}gc) {
            push @lines, [undef, undef, $line];
            next;
        }
        if ($line =~ m{\G($prefix_re)}gc) {
            $prefix .= $1;
        }
        my $key;
        if ($line =~ m{\G($prefix_re)($key_re)}gc) {
            $key = $2;
            $prefix .= $1 . $2;
        }
        else {
            _fail(\$line, $name, $ln, 'variable name');
        }

        if ($line =~ m{\G($assign_re)}gc) {
            $prefix .= $1;
        }
        else {
            _fail(\$line, $name, $ln, 'assignment');
        }

        my $value = '';
        my $value_text = '';
        while ($line =~ m{\G($value_re)}gc) {
            my $part = $1;
            $value_text .= $part;
            if ($part =~ s/\A"(.*)"\z/$1/) {
                $part =~ s{(\\$unescape_re)}{$unescape{$1}}g;
            }
            elsif ($part =~ s/\A'(.*)'\z/$1/) {
            }
            else {
                $part =~ s{\\(.)}{$1}g;
            }
            $value .= $part;
        }

        my $post = '';
        if (pos $line == length $line) {
        }
        elsif ($line =~ m{\G(\s+#.*|\s*\z)}gc) {
            $post = $1;
        }
        elsif ($line =~ m{\G\s+}gc) {
            _fail(\$line, $name, $ln, 'comment or end of line');
        }
        else {
            _fail(\$line, $name, $ln, 'value, comment, or end of line');
        }

        my $entry = [$key, $value, $prefix, $value_text, $post];
        push @lines, $entry;
        if (exists $settings{$key}) {
            carp "Found duplicate setting '$key' at $name line $ln";
            $settings{$key}[1] = undef;
        }
        $settings{$key} = $entry;
    }

    $self->delete($_)
        for grep exists $self->{settings}{$_}, keys %settings;
    push @{$self->{lines}}, @lines;
    %{ $self->{settings} } = (
        %{ $self->{settings} },
        %settings,
    );
    return $self;
}

sub exists {
    my ($self, $key) = @_;
    return exists $self->{settings}{$key};
}

sub get {
    my ($self, $key) = @_;
    my $ref = $self->{settings}{$key};
    return $ref && $ref->[1];
}

sub set {
    my ($self, $key, $value) = @_;

    croak "Value must be defined!"
        if !defined $value;
    croak "Value must be a plain scalar or object with overloads!"
        if ref $value and (
            !blessed $value
            or !$INC{"overload.pm"}
            or eval { overload::StrVal($value) eq "$value" }
        );
    $value = "$value";
    my $escaped = $self->_escape($value);
    my $ref = $self->{settings}{$key};
    if ($ref) {
        $ref->[1] = $value;
        $ref->[3] = $escaped;
    }
    else {
        my ($key_re, $key_desc) =
            $self->{strict} ? (
                $key_strict_re,
                'alphanumeric character',
            ) : (
                $key_loose_re,
                'word character',
            );
        unless ($key =~ /\A($key_re)/g && length $key == length $1) {
            my $char = 1 + length $1;
            croak qq{Invalid key at character $char, expected $key_desc:\n$key\n}
                . ( '-' x ($char-1) ) . "^\n";
        }
        my $entry = [ $key, $value, "$key=", $escaped ];
        push @{$self->{lines}}, $entry;
        $self->{settings}{$key} = $entry;
    }
    return $value;
}

sub as_hashref {
    my ($self) = @_;
    return { $self->as_hash };
}

sub as_hash {
    my ($self) = @_;
    return
        map +( $_->[0], $_->[1] ),
        grep defined $_->[1],
        @{ $self->{lines} };
}

sub keys {
    my ($self) = @_;
    return
        map $_->[0],
        grep defined $_->[1],
        @{ $self->{lines} };
}

sub delete {
    my ($self, $key) = @_;
    my $ref = delete $self->{settings}{$key};
    if ($ref) {
        my $value = $ref->[1];
        @{ $self->{lines} }
            = grep !(defined $_->[0] && $_->[0] eq $key),
            @{ $self->{lines} };
        return $value;
    }
    return undef;
}

sub lines {
    my $self = shift;
    return
        map join('', @{$_}[2 .. $#$_], "\n"),
        grep defined && @$_ > 2,
        @{ $self->{lines} };
}

sub content {
    my $self = shift;
    return join '', $self->lines;
}

sub write {
    my ($self, $file) = @_;
    open my $fh, '>:utf8', $file
        or die "Unable to write to $file: $!";
    print $fh $self->content;
    close $fh;
    return $file;
}

1;
__END__

=head1 NAME

Dotenv::File - An object for reading and writing Dotenv files

=head1 SYNOPSIS

C<config.env>:

    SETTING_ONE=1

    SETTING_TWO=2  # important

    #More settings:
    SETTING_THREE=3
        SETTING_FOUR=4
    SETTING_FIVE=5

Using file:

    my $env = Dotenv::File->read('config.env');
    my $two = $env->get('SETTING_TWO');
    $two *= 2;
    $env->set('SETTING_TWO' => $two);
    $env->delete('SETTING_THREE');
    $env->set('SETTING_FOUR' => 'with extra lemon');
    $env->set('SETTING_FIVE' => "now that's paper \$");
    $env->write('new_config.env');

C<new_config.env>:

    SETTING_ONE=1

    SETTING_TWO=0  # important

    #More settings:
    SETTING_THREE=3
        SETTING_FOUR='with extra lemon'
    SETTING_FIVE="now that's paper \$"

=head1 DESCRIPTION

B<Dotenv::File> allows reading and modifying dotenv configuration files, while
maintaining the order and comments of the original file.

=head1 METHODS

=head2 new

=head3 options

=over 4

=item strict

Default false.  In strict mode, only things that can actually be parsed by a
shell will be accepted.  When strict is off, whitespace is allowed surrouding
the =, keys can include any word character as well as C<.> and C<->, and C<\n>
sequences in values are translated to real newline characters.

=item export

Default to the inverse of the strict flag.  Allows a leading C<export > on
entries.

=item settings

A hashref or arrayref of settings to apply in the inital object.

=back

=head2 read

=over 4

=item Dotenv::File->read($file, %options);

=item Dotenv::File->new->read($file);

=back

Reads a dotenv file and returns a Dotenv::File object to access or modify it.

Can be called on an existing object, or as a class method.  When called as a
class method, also accepts the same options as the new method.

If duplicate settings already exist in the object, they will be deleted.
Duplicates within the content being read will trigger warnings, but their
content will be maintained in the output text.

=head2 get

Gets a value.

=head2 set

Sets a value.

=head2 exists

Check if a key exists.

=head2 delete

Deletes a key.  The entire line the key exists on will be removed.

=head2 keys

Returns a list of keys that are set, in the same order they were read from the
file.

=head2 as_hash

Returns a list of key value pairs, in the same order they were read from the
file.

=head2 as_hashref

Returns the values from the file as a hashref.

=head2 lines

Returns the content of the file as a list of lines, including terminating
newlines.

=head2 content

Returns the full content of the file as a string.

=head2 write

Writes the content to a file.

=head1 AUTHORS

See L<Dotenv> for authors.

=head1 COPYRIGHT AND LICENSE

See L<Dotenv> for the copyright and license.

=cut
