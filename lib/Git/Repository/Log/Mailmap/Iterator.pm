package Git::Repository::Log::Mailmap::Iterator;

use warnings;
use strict;
use Carp;
use 5.006;

=head1 NAME

Git::Repository::Log::Mailmap::Iterator - Split a git log, with mailmap


=head1 VERSION

This document describes Git::Repository::Log::Mailmap::Iterator version 0.0.3


=cut

use version;
our $VERSION = qv('0.0.3');

=head1 SYNOPSIS

 use Git::Repository::Log::Mailmap::Iterator;

 # use .mailmap or git-config mailmap.file, mailmap.blob
 my $iter = Git::Repository::Log::Mailmap::Iterator($r);
 while (my $log = $iter->next) {
   ...
 }

 # or ignore default
 my $iter = Git::Repository::Log::Mailmap::Iterator($r, '--no-use-mailmap');
 # and init mailmap with Git::Mailmap
 $iter->mailmap->from_string(mailmap => $mailmap_file_as_string);


=cut

use parent qw(Git::Repository::Log::Iterator);

use File::Slurp qw/ slurp /;
use File::Spec::Functions qw/ catfile /;
use Git::Mailmap;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->init_mailmap(@_);
  $self;
}


sub init_mailmap {
  my ($self, $r) = @_;

  $self->{mailmap} = Git::Mailmap->new();
  return if grep { $_ eq '--no-use-mailmap' } @_;

  my $log_mailmap = $r->run(config => 'log.mailmap');
  my $mailmap;
  if ($log_mailmap eq 'true') {
    if (my $file = $r->run(config => 'mailmap.file')) {
      $mailmap = slurp $file;
    }
    elsif (my $blob = $r->run(config => 'mailmap.blob')) {
      $mailmap = $r->run('cat-file' => '-p' => $blob);
    }
    else {
      my $file = catfile($r->work_tree, '.mailmap');
      $mailmap = slurp $file;
    }
  }
  $self->{mailmap}->from_string(mailmap => $mailmap) if $mailmap;
}


sub mailmap {
  shift->{mailmap};
}


sub next {
  my ($self) = @_;
  my $log = $self->SUPER::next(@_);

  if ($log && $self->mailmap) {
    for my $who (qw/ author committer /) {
      $log->{"raw_$who"} = $log->{$who};
      my ($name, $email) = $self->mailmap->map(
        email => "<".$log->{"${who}_email"}.">",
        name => $log->{"${who}_name"}
       );
      $log->{"${who}_name"} = $name if $name;
      ($log->{"${who}_email"} = $email) =~ s/<(.*)>/$1/ if $email;
      $self->{$who} = join(' ', @{$log}{
        "${who}_name", "${who}_email", "${who}_gmtime", "${who}_tz",
      });
    }
  }

  $log;
}


1;
__END__

=head1 AUTHOR

KUBO Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
