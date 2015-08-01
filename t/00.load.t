use Test::More;

my @mod;

BEGIN {
  @mod = map { "Git::Repository::$_" }
    qw/ Plugin::Log::Mailmap Log::Mailmap::Iterator /;
  use_ok($_) for @mod;
}

diag "Testing $_ ", eval "\$${_}::VERSION" for @mod;

done_testing;
