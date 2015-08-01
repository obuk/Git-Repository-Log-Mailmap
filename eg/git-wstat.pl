#!/usr/bin/env perl

package git::wstats;

use warnings;
use strict;
use Carp;

=encoding utf8

=head1 NAME

git::wstats - gets activities, per week or month, per (wo)man


=cut

use version;
our $VERSION = qv('0.0.3');

=head1 SYNOPSIS

 git-wstats.pl repo1 repo2 ...   # stats weekly
 DEBUG=1 git-wstats.pl

and

 ln -s git-wstats.pl git-mstats.pl
 git-mstats.pl repo1 repo2 ...   # stats monthly


=cut

use DateTime;
use Encode::Locale;
use File::Spec::Functions qw/ catdir splitdir catfile /;
use Git::Repository qw(Log::Mailmap);
use List::Util qw(sum max min);
use Perl6::Say;
use Perl6::Slurp;
use POSIX qw(ceil);
use utf8;


sub DEBUG () {
  no warnings 'uninitialized';
  $ENV{DEBUG} + 0;
}


sub run {
  my $class = shift;
  return $class->new(@_)->process() || 0;
}


sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = bless { @_ }, $class;
  $self->init();
  $self;
}


sub init {
  my $self = shift;
  @ARGV = grep { !$self->git_dir($_) } @ARGV;
  $self->git_dir('.') unless $self->git_dir;
  $self->init_periodic;
  $self;
}


sub init_periodic {
  my $self = shift;
  $self->_init_weekly();
  # $self->_init_monthly();
}


sub _init_weekly {
  my $self = shift;
  $self->{week_number} //= "week_number";
  $self->{dow}         //= "dow";
  $self->{week_label}  //= [qw/ Mo Tu We Th Fr Sa Su /];
  $self->{week_index}  //= [ 1 .. 7 ];
  $self->{days}        //= 5;
}


sub _init_monthly {
  my $self = shift;
  $self->{week_number} //= "month";
  $self->{dow}         //= "day";
  $self->{week_label}  //= [ map { sprintf("%02d", $_) } 1 .. 31 ];
  $self->{week_index}  //= [ 1 .. 31 ];
  $self->{days}        //= 20;
}


sub git_dir {
  my ($self, $dir) = @_;
  $self->{git_dir} //= [];
  if ($dir) {
    my $git_dir;
    if (-d $dir) {
      $git_dir = eval { Git::Repository->new(git_dir => $dir ) } ||
        eval { Git::Repository->new(git_dir => catdir($dir, '.git')) };
    }
    if ($git_dir) {
      DEBUG > 2 and say "# git_dir: $git_dir->{git_dir}";
      push @{$self->{git_dir}}, $git_dir;
    }
    return $git_dir;
  }
  @{$self->{git_dir}};
}


sub process {
  my $self = shift;

  my @argv = (qw/--no-merges --use-mailmap/, @ARGV);
  my @git; my %seen;
  for my $r ($self->git_dir) {
    next if $seen{$r->{git_dir}}++;
    DEBUG > 1 and say join(' ', "# git --git-dir=".$r->git_dir, "log", @argv);
    my $iterator = $r->log_mailmap(@argv);
    # binmode $iterator->{fh}, ":encoding($enc)";
    my $log = $iterator->next;
    push @git, { git_dir => $r->git_dir, iterator => $iterator, log => $log };
  }

  my $reverse = grep { $_ eq '--reverse' } @argv;
  my $week_number = $self->{week_number};
  my @log; my $last_cd;

  while (@git) {
    @git = sort {
      $reverse?
        $a->{log}->committer_gmtime <=> $b->{log}->committer_gmtime :
        $b->{log}->committer_gmtime <=> $a->{log}->committer_gmtime
    } @git if @git > 1;
    my $log = $git[0]->{log};

    my $cd = DateTime->from_epoch(
      epoch => $log->committer_gmtime, time_zone => $log->committer_tz
     );

    if ($last_cd && ($cd->$week_number != $last_cd->$week_number)) {
      $self->periodic(@log);
      @log = ();
    }

    if (DEBUG > 1) {
      say $_ for
        join(' ', 'commit', $log->commit),
        join(' ', 'git_dir', $git[0]->{git_dir}),
        join(' ', 'Author:', $log->author_name, '<'.$log->author_email.'>'),
        join(' ', 'Date:  ', $cd->strftime("%F %T %z")),
        '',
        (map '    '.$_, split "\n", $log->message),
        '';
    }

    push @log, $log;
    $last_cd = $cd;

    shift @git unless $git[0]->{log} = $git[0]->{iterator}->next;
  }

  $self->periodic(@log) if @log;

  return 0;
}


sub periodic {
  my $self = shift;
  return unless @_;

  my $dow = $self->{dow};
  my $week_number = $self->{week_number};
  my @week_label = @{$self->{week_label}};

  for (@_) {
    my $ad = DateTime->from_epoch(
      epoch => $_->author_gmtime, time_zone => $_->author_tz,
     );
    my $fixes = $_->message =~ /\b fix(?:es|ed)? \b /x;
    $self->{calendar}{ $ad->ymd }{hr}{ $ad->hour }++;
    $self->{calendar}{ $ad->ymd }{au}{ $_->author_email }++;
    $self->{calendar}{ $ad->ymd }{r}++ if $fixes;
    $self->{calendar}{ $ad->ymd }{c}++;
  }

  my $ad = DateTime->from_epoch(
    epoch => $_[0]->author_gmtime, time_zone => $_[0]->author_tz,
   );
  $ad->subtract(days => $ad->$dow - 1);

  my %count; my ($c, $r) = (0, 0);
  for my $dow (@{$self->{week_index}}) {
    my $dt = $ad->clone; $dt->add(days => $dow - 1);
    $count{ $dow } = $self->{calendar}{ $dt->ymd };
    $r += $self->{calendar}{ $dt->ymd }{r} // 0;
    $c += $self->{calendar}{ $dt->ymd }{c} // 0;
  }

  # counts number of authors worked day by day
  my %md;
  for (values %count) {
    for (keys %{$_->{au}}) {
      $md{$_}++;
    }
  }

  if (DEBUG) {
    my %au;
    say join(' ', '#', '  ', map { $_ % 10 } 0 .. 23);
    for my $dow (@{$self->{week_index}}) {
      my $dt = $ad->clone->add(days => $dow - 1);
      if ($count{$dow}{c} || $count{$dow}{r}) {
        my %c = %{$count{$dow}};
        my $x = join(' ', map { $c{hr}{$_} || '.' } 0 .. 23);
        my @w = sort { $c{au}{$b} <=> $c{au}{$a} } keys %{$c{au}};
        my $w = join(' ', map { $self->_shorten($_, $c{au}{$_}) } @w);
        $au{$_} += $c{au}{$_} for @w;
        say join(' ', '#', $week_label[$dow - 1], $x, $w);
      } else {
        last if $dt->$week_number != $ad->$week_number;
        say join(' ', '#', $week_label[$dow - 1]);
      }
    }
    say '#';
    my $w = ceil(log(max(1, values %au)) / log(10));
    say join(' ', '#', sprintf("%${w}d", $au{$_}), $self->_shorten($_), $_)
      for sort keys %md;
    say '#';
  }

  my $m = scalar keys %md;
  my $md = sum(values %md);
  my $mD = $m * $self->{days};
  my ($x, @x) = map sprintf("%.2f", $_), $r / $c, $c / $md, $md / $mD;
  if (my $n = $self->{calendar}{ $ad->ymd }{seen}++) { push @x, "# $n" }
  say join("\t", '# __date__', qw(c r r/c md m c/md md/mD)) unless $self->{h}++;
  say join("\t", $ad->ymd, $c, $r, $x, $md, $m, @x);
  ($c, $r, $md, $m, $mD);
}


sub _shorten {
  my $self = shift;
  my ($name, $count) = @_;
  (my $s = $name) =~ s/[^\w]//g;
  $count = '' if !$count || $count <= 1;
  $count . substr($s, 0, 2);
}

1;

package main;
our @ISA = qw(git::wstats);
sub init_periodic {
  shift->_init_weekly  if $0 =~ /git-w/;
  shift->_init_monthly if $0 =~ /git-m/;
}
exit(__PACKAGE__->run());

__END__

=head1 SEE ALSO

L<Git::Repository::Plugin::Log::Mailmap>

=head1 AUTHOR

KUBO, Koichi  C<< <k@obuk.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, KUBO, Koichi C<< <k@obuk.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
