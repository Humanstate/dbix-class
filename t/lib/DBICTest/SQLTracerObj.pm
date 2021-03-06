package # moar hide
  DBICTest::SQLTracerObj;

use strict;
use warnings;

use base 'DBIx::Class::Storage::Statistics';

sub query_start {
  my ($self, $sql, $bind) = @_;

  my $op = ($sql =~ /^\s*(\S+)/)[0];

  $sql =~ s/^ \s* \Q$op\E \s+ \[ .+? \]/$op/x
    if $ENV{DBICTEST_VIA_REPLICATED};

  push @{$self->{sqlbinds}}, [ $op, [ $sql, @{ $bind || [] } ] ];
}

# who the hell came up with this API >:(
for my $txn (qw(begin rollback commit)) {
  no strict 'refs';
  *{"txn_$txn"} = sub { push @{$_[0]{sqlbinds}}, [ uc $txn => [ uc $txn ] ] };
}

sub svp_begin { push @{$_[0]{sqlbinds}}, [ SAVEPOINT => [ "SAVEPOINT $_[1]" ] ] }
sub svp_release { push @{$_[0]{sqlbinds}}, [ RELEASE_SAVEPOINT => [ "RELEASE $_[1]" ] ] }
sub svp_rollback { push @{$_[0]{sqlbinds}}, [ ROLLBACK_TO_SAVEPOINT => [ "ROLLBACK TO $_[1]" ] ] }

1;
