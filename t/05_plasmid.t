#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw/$RealBin/;
use Test::More tests=>9;

# Set up the path to include this instance of prokka
$ENV{PATH}="$RealBin/../bin:".$ENV{PATH};

my $log = "$0.log";
# truncate the log file
open(my $fh, ">", $log) or BAIL_OUT("ERROR: could not truncate log file $log: $!");
close $fh;

# Ensure any previous tests do not override this one
unlink $_ for(glob("asm/*"));
rmdir "asm";

for my $cmd(
  "prokka --version",
  "prokka --help",
  "! prokka --doesnotexist",
  "prokka --depends",
  "prokka --setupdb",
  "prokka --listdb",
  "prokka --cpus 2 --outdir asm --prefix asm test/plasmid.fna",
  "grep '>' asm/asm.fna",
  "prokka --cleandb",
){ 
  my $hr = '=' x 10;
  open(my $fh, ">>", $log) or BAIL_OUT("ERROR: could not write to log file $log: $!");
  print $fh "\n$hr\n$cmd\n$hr\n";
  close $fh;

  system($cmd ." >> $log 2>&1");
  is($?, 0, "Command: $cmd");
}

END{
  diag "Log file can be found in $log";
}
