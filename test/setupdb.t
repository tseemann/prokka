#!/usr/bin/env perl

use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

my $source = do {
  open my $fh, '<', File::Spec->catfile('bin', 'prokka') or die $!;
  local $/;
  <$fh>;
};

my ($hmm_files) = $source =~ /(sub hmm_files \{.*?^\}\n)/ms;
ok($hmm_files, 'found the production HMM selection helper') or BAIL_OUT('cannot test HMM setup');
eval "$hmm_files 1;";
die $@ if $@;

my ($clean_db) = $source =~ /(sub clean_db \{.*?^\}\n)/ms;
ok($clean_db, 'found the production database cleanup helper') or BAIL_OUT('cannot test database cleanup');
our $dbdir;
sub msg { }
sub delfile {
  unlink $_ for @_;
}
eval "$clean_db 1;";
die $@ if $@;

sub legacy_hmm_files {
  my($dir) = @_;
  return <$dir/*.{hmm,hmm.gz}>;
}

sub mock_setupdb {
  my($dir, $selector) = @_;
  $selector ||= \&hmm_files;
  my @commands;
  unlink $_ for glob "$dir/*.h3?";
  for my $hmm ($selector->($dir)) {
    if ($hmm =~ m/\.gz$/) {
      (my $uncompressed = $hmm) =~ s/\.gz$//;
      push @commands, "gzip -dc $hmm > $uncompressed";
      open my $in, '<', $hmm or die $!;
      open my $out, '>', $uncompressed or die $!;
      while (<$in>) { print {$out} $_ }
      close $out;
      close $in;
      $hmm = $uncompressed;
    }
    mock_hmmpress($hmm, \@commands);
  }
  return \@commands;
}

sub mock_hmmpress {
  my($hmm, $commands) = @_;
  my @index_files = map { "$hmm.$_" } qw(h3f h3i h3m h3p);
  die "mock hmmpress refused existing indices for $hmm\n"
    if grep { -e $_ } @index_files;
  push @$commands, "hmmpress $hmm";
  for my $index (@index_files) {
    open my $fh, '>', $index or die $!;
    close $fh;
  }
}

my $dir = tempdir(CLEANUP => 1);
open my $hmm, '>', "$dir/HAMAP.hmm" or die $!;
print {$hmm} "HMMER3/f\n";
close $hmm;
open my $gz, '>', "$dir/HAMAP.hmm.gz" or die $!;
print {$gz} "compressed fixture\n";
close $gz;
open my $other_gz, '>', "$dir/OTHER.hmm.gz" or die $!;
print {$other_gz} "compressed fixture\n";
close $other_gz;

is_deeply([hmm_files($dir)], ["$dir/HAMAP.hmm", "$dir/OTHER.hmm.gz"],
  'an existing uncompressed HMM wins over its compressed twin');

my $legacy_error;
eval { mock_setupdb($dir, \&legacy_hmm_files); 1 }
  or $legacy_error = $@;
like($legacy_error, qr/mock hmmpress refused existing indices for .*HAMAP\.hmm/,
  'the legacy HMM glob reproduces duplicate hmmpress failure');

my $first = mock_setupdb($dir);
is_deeply($first, [
  "hmmpress $dir/HAMAP.hmm",
  "gzip -dc $dir/OTHER.hmm.gz > $dir/OTHER.hmm",
  "hmmpress $dir/OTHER.hmm",
], 'setupdb presses each logical HMM only once');
my $second = mock_setupdb($dir);
is_deeply($second, [
  "hmmpress $dir/HAMAP.hmm",
  "hmmpress $dir/OTHER.hmm",
], 'repeated setupdb remains single-pass without duplicate hmmpress');
ok(-e "$dir/HAMAP.hmm.h3i", 'mock hmmpress produced an index');

my $only_gz = tempdir(CLEANUP => 1);
open my $only, '>', "$only_gz/ONLY.hmm.gz" or die $!;
print {$only} "compressed fixture\n";
close $only;
is_deeply([hmm_files($only_gz)], ["$only_gz/ONLY.hmm.gz"],
  'a compressed-only HMM is still selected');
is_deeply(mock_setupdb($only_gz), [
  "gzip -dc $only_gz/ONLY.hmm.gz > $only_gz/ONLY.hmm",
  "hmmpress $only_gz/ONLY.hmm",
], 'compressed-only setupdb still expands then presses once');

my $clean_root = tempdir(CLEANUP => 1);
make_path("$clean_root/hmm");
for my $file (glob "$dir/HAMAP.hmm*") {
  open my $in, '<', $file or die $!;
  (my $name = $file) =~ s{^\Q$dir\E[\\/]}{};
  open my $out, '>', "$clean_root/hmm/$name" or die $!;
  while (<$in>) { print {$out} $_ }
  close $out;
  close $in;
}
$dbdir = $clean_root;
clean_db(0);
ok(-e "$clean_root/hmm/HAMAP.hmm", 'clean_db contract preserves the source HMM');
ok(-e "$clean_root/hmm/HAMAP.hmm.gz", 'clean_db contract preserves the compressed source HMM');
ok(!-e "$clean_root/hmm/HAMAP.hmm.h3i", 'clean_db removes generated HMM indices');

done_testing;
