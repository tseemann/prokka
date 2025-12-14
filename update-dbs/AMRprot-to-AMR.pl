#!/usr/bin/env perl
use strict;

#0 >WP_002791310.1|   
#1 1|
#2 B1|
#3 blaOXA-489|
#4 blaOXA-61_fam|
#5 hydrolase|
#6 2|
#7 BETA-LACTAM|
#8 BETA-LACTAM|
#9 OXA-61_family_class_D_beta-lactamase_OXA-489 

#>NG_049762.1
#~~~blaOXA-48
#~~~carbapenem-hydrolyzing class D beta-lactamase OXA-48
#~~~

while (<>) {
  if (m/^>(.*)$/) {
    my $hdr = $1;
    chomp $hdr;
    my @f = split m/\|/, $hdr;
    $f[9] =~ s/_/ /g;
    print 
      ">$f[0] ",
      join('~~~',
        '',    # /EC_number
        $f[3], # /gene
        $f[9], # /productr
        '',    # COG
      ),
      "\n";
  }
  else {
    print $_;
  }
}
