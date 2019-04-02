use strict;
use warnings;
use Test::More;
use Dotenv::File;
use Data::Dumper ();

my $dotenv = Dotenv::File->read(\<<'END_DOTENV');
#a asd asd
foo=1

bar=welp #guff

#boy howdy
END_DOTENV

$dotenv->set(foo => "oh no");

my $out = '';
$dotenv->write(\$out);

is $out, <<'END_DOTENV';
#a asd asd
foo='oh no'

bar=welp #guff

#boy howdy
END_DOTENV

$dotenv->set(bar => "blorp");
$out = '';
$dotenv->write(\$out);

is $out, <<'END_DOTENV';
#a asd asd
foo='oh no'

bar=blorp #guff

#boy howdy
END_DOTENV

$dotenv->delete('bar');
$out = '';
$dotenv->write(\$out);

is $out, <<'END_DOTENV';
#a asd asd
foo='oh no'


#boy howdy
END_DOTENV

my $clone = do {
    no strict;
    eval Data::Dumper::Dumper($dotenv) or die $@;
};
$clone->set(Foo => 1);

$clone->write(\$out);

ok 1;
done_testing;
