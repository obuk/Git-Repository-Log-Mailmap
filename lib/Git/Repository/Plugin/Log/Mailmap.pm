package Git::Repository::Plugin::Log::Mailmap;

use 5.006;
use warnings;
use strict;
use Carp;

=head1 NAME

Git::Repository::Plugin::Log::Mailmap - git log, with mailmap


=head1 VERSION

This document describes Git::Repository::Plugin::Log::Mailmap version 0.0.6


=cut

use version;
our $VERSION = qv('0.0.6');

=head1 SYNOPSIS

    # load mailmap plugin
    use Git::Repository 'Log::Mailmap';

    # setup mailmap on the repo
    my $r = Git::Repository->new(git_dir => $gitdir);
    $r->mailmap->default;  # or $r->mailmap->from_string(...);

    # mailmap behavior from git-config log.mailmap
    my $iter = $r->log;
    while (my $log = $iter->next) {
        ...;
    }

    # or it's from option --use-mailmap and --no-use-mailmap
    my $iter = $r->log('--use-mailmap');


=cut

use Git::Repository::Plugin;
our @ISA      = qw( Git::Repository::Plugin );
sub _keywords { qw( log_mailmap mailmap ) }

use Git::Repository qw( Log );
# use Git::Repository::Plugin::Log;
use Git::Repository::Log::Iterator;

use Git::Repository::Plugin::Log::Mailmap::Default;
use Hook::WrapSub qw( wrap_subs unwrap_subs );

wrap_subs
  sub { },
  'Git::Repository::Log::Iterator::new',
  sub {
    my ($class, $r) = @_;
    my ($iter) = @Hook::WrapSub::result;
    $iter->{r} = $r;
    my $log_mailmap = ($r->run(config => 'log.mailmap') || '') =~ /true/;
    for (@_) {
      $log_mailmap = 0 if /^--no-use-mailmap$/;
      $log_mailmap = 1 if /^--use-mailmap$/;
      last             if /^--$/;
    }
    $r->mailmap->default if $r->{log_mailmap} = $log_mailmap;
  };

wrap_subs
  sub { },
  'Git::Repository::Log::Iterator::next',
  sub {
    my ($self, @args) = @_;
    my ($mailmap, $log_mailmap) = @{$self->{r}}{qw/ mailmap log_mailmap /};
    if ($mailmap && $log_mailmap) {
      for (grep { $_ } @Hook::WrapSub::result) {
        for my $who (qw/ author committer /) {
          $_->{"raw_$who"} = $_->{$who};
          my ($name, $email) = $mailmap->map(
            email => "<".$_->{"${who}_email"}.">",
            name => $_->{"${who}_name"}
           );
          $_->{"${who}_name"} = $name if $name;
          ($_->{"${who}_email"} = $email) =~ s/<(.*)>/$1/ if $email;
          $self->{$who} = join(' ', @{$_}{
            "${who}_name", "${who}_email", "${who}_gmtime", "${who}_tz",
          });
        }
      }
    }
  };

sub log_mailmap {
  goto &Git::Repository::Plugin::Log::log;
}

sub mailmap {
  # skip the invocant when invoked as a class method
  shift if !ref $_[0];
  my $r = shift;
  unless ($r->{mailmap}) {
    $r->{mailmap} = Git::Repository::Plugin::Log::Mailmap::Default->new($r);
  }
  $r->{mailmap};
}

1;
__END__

=head1 SEE ALSO

L<Git::Repository::Plugin::Log::Mailmap::Default>,
L<Git::Repository::Log>


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to the web interface at
L<https://github.com/obuk/Git-Repository-Plugin-Log-Mailmap/issues>


=head1 AUTHOR

KUBO Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
