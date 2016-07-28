BEGIN { do "./t/lib/ANFANG.pm" or die ( $@ || $! ) }

use strict;
use warnings;

use Test::More;

use DBICTest ':DiffSQL';
use DBIx::Class::SQLMaker::LimitDialects;

my $ROWS = DBIx::Class::SQLMaker::LimitDialects->__rows_bindtype;

my $schema = DBICTest->init_schema();

my $cd_rs = $schema->resultset('CD')->search (
  { 'tracks.cd' => { '!=', undef } },
  { prefetch => 'tracks' },
);

# Database sanity check
is($cd_rs->count, 5, 'CDs with tracks count');
for ($cd_rs->all) {
  is ($_->tracks->count, 3, '3 tracks for CD' . $_->id );
}

{
  my $most_tracks_rs = $schema->resultset ('CD')->search (
    {},
    {
      join => 'tracks',
      prefetch => 'liner_notes',
      group_by => 'me.artist', # 3 distinct artists in the test schema
                               # so we should have no more than 3 rows
      rows => 10,
      page => 1,
    }
  );

  is_same_sql_bind(
    $most_tracks_rs->as_query,
    '(
        SELECT me.cdid, me.artist, me.title, me.year, me.genreid, me.single_track, liner_notes.liner_id, liner_notes.notes
        FROM (
            SELECT me.cdid, me.artist, me.title, me.year, me.genreid, me.single_track
            FROM cd me
            GROUP BY me.artist LIMIT ?
        ) me
        LEFT JOIN liner_notes liner_notes ON liner_notes.liner_id = me.cdid
    )',
    [[$ROWS => 10]],
    'Oddball mysql-ish group_by usage yields valid SQL',
  );

  my $i;
  $i++ while $most_tracks_rs->next;

  is( $i,3,'row count after ->next iteration' );
  is( $most_tracks_rs->count,$i,'->count' );
  is( $most_tracks_rs->pager->total_entries,$i,'pager groups on cd.artist' );
}

done_testing;
