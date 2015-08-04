package Git::Repository::Plugin::Log::Mailmap::Default;

use 5.006;
use warnings;
use strict;
use Carp;

=head1 NAME

Git::Repository::Plugin::Log::Mailmap::Default -


=head1 VERSION

This document describes Git::Repository::Plugin::Log::Mailmap::Default version 0.0.5


=cut

use version;
our $VERSION = qv('0.0.5');


=head1 SYNOPSIS

    use Git::Repository::Plugin::Log::Mailmap::Default;
    my $r = Git::Repository->new(git_dir => $gitdir);

    my $mailmap = Git::Repository::Plugin::Log::Mailmap::Default->new($r);
    $mailmap->default();
    # or $mailmap->from_string(mailmap => $mailmap_file_as_string);


=cut


use parent qw/ Git::Mailmap /;
use File::Slurp qw/ slurp /;
use File::Spec::Functions qw/ catfile /;
use Hash::Util qw/ lock_keys unlock_keys lock_keys_plus /;

sub new {
  my $class = shift;
  my $r = @_ && ref $_[0] && $_[0]->isa('Git::Repository') && shift;
  my $self = $class->SUPER::new(@_);
  unlock_keys(%$self);
  lock_keys_plus(%$self, 'r');
  $self->{r} = $r if $r;
  $self;
}


sub r {
  my $self = shift;
  $self->{r} = shift if @_;
  $self->{r};
}


sub default {
  my $self = shift;
  my $r = $self->r;

  my $mailmap;
  if (my ($file) = glob $r->run(config => 'mailmap.file')) {
    $mailmap = slurp $file;
  }
  elsif (my $blob = $r->run(config => 'mailmap.blob')) {
    $mailmap = $r->run('cat-file' => '-p' => $blob);
  }
  else {
    my $file = catfile($r->work_tree, '.mailmap');
    if ($file && -f $file) {
      $mailmap = slurp $file
    }
  }

  $self->from_string(mailmap => $mailmap) if $mailmap;
  $self;
}

1;

__END__

=head1 SEE ALSO

L<Git::Mailmap>,


=head1 AUTHOR

KUBO Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
