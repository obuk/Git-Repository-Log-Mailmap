package Git::Repository::Plugin::Log::Mailmap;

use 5.006;
use warnings;
use strict;
use Carp;

=head1 NAME

Git::Repository::Plugin::Log::Mailmap - git log, with mailmap


=head1 VERSION

This document describes Git::Repository::Plugin::Log::Mailmap version 0.0.5


=cut

use version;
our $VERSION = qv('0.0.5');

=head1 SYNOPSIS

    use Git::Repository 'Log::Mailmap';
    my $r = Git::Repository->new;
    my $iter = $r->log;
    while (my $log = $iter->next) {
        ...;
    }


=cut

use Git::Repository::Plugin;
our @ISA      = qw( Git::Repository::Plugin );
sub _keywords { qw( log_mailmap ) }

use Git::Repository qw( Log );
# use Git::Repository::Plugin::Log;
use Git::Repository::Log::Mailmap::Iterator;
use Git::Repository::Log::Iterator;

use Hook::WrapSub qw( wrap_subs unwrap_subs );

wrap_subs
  sub { },
  'Git::Repository::Log::Iterator::new',
  sub {
    my ($class, @args) = @_;
    my ($self) = @Hook::WrapSub::result;
    $self->Git::Repository::Log::Mailmap::Iterator::init_mailmap(@args);
  };

wrap_subs
  sub { },
  'Git::Repository::Log::Iterator::next',
  sub {
    my ($self, @args) = @_;
    for (@Hook::WrapSub::result) {
      $self->Git::Repository::Log::Mailmap::Iterator::apply_mailmap($_);
    }
  };


unless (Git::Repository::Log::Iterator->can('mailmap')) {
  no strict 'refs';
  *{"Git::Repository::Log::Iterator::mailmap"} =
    \&Git::Repository::Log::Mailmap::Iterator::mailmap;
}


sub log_mailmap {
  goto &Git::Repository::Plugin::Log::log;
}

1;
__END__

=head1 SEE ALSO

L<Git::Repository::Log>,
L<Git::Mailmap>,


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to the web interface at
L<https://github.com/obuk/Git-Repository-Log-Mailmap/issues>


=head1 AUTHOR

KUBO Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
