package SWISS::CRC64;
   
# ** Initialisation
#32 first bits of generator polynomial for CRC64
#the 32 lower bits are assumed to be zero
my $POLY64REVh = 0xd8000000; 
my @CRCTableh = 256;
my @CRCTablel = 256;
my $initialized;


sub crc64 {	
  my $sequence = shift;
  my $crcl = 0;
  my $crch = 0;
  if (!$initialized) {
    $initialized = 1;
    for (my $i=0; $i<256; $i++) {
      my $partl = $i;
      my $parth = 0;
      for (my $j=0; $j<8; $j++) {
	my $rflag = $partl & 1;
	$partl >>= 1;
	$partl |= (1 << 31) if $parth & 1;
	$parth >>= 1;
	$parth ^= $POLY64REVh if $rflag;
      }
      $CRCTableh[$i] = $parth;
      $CRCTablel[$i] = $partl;
    }
  }
  
  foreach (split '', $sequence) {
    my $shr = ($crch & 0xFF) << 24;
    my $temp1h = $crch >> 8;
    my $temp1l = ($crcl >> 8) | $shr;
    my $tableindex = ($crcl ^ (unpack "C", $_)) & 0xFF;
    $crch = $temp1h ^ $CRCTableh[$tableindex];
    $crcl = $temp1l ^ $CRCTablel[$tableindex];
  }
  return wantarray ? ($crch, $crcl) : sprintf("%08X%08X", $crch, $crcl);
}
  
    
1;  

__END__

=head1 CRC64 perl module documentation

=head2 NAME

CRC64 - Calculate the cyclic redundancy check.

=head2 SYNOPSIS

   use SWISS::CRC64;
   
   $crc = SWISS::CRC64::crc64("IHATEMATH");
   #returns the string "E3DCADD69B01ADD1"

   ($crc_low, $crc_high) = SWISS::CRC64::crc64("IHATEMATH");
   #returns two 32-bit unsigned integers, 3822890454 and 2600578513

=head2 DESCRIPTION

SWISS-PROT + TREMBL use a 64-bit Cyclic Redundancy Check for the
amino acid sequences. 

The algorithm to compute the CRC is described in the ISO 3309
standard.  The generator polynomial is x64 + x4 + x3 + x + 1.
Reference: W. H. Press, S. A. Teukolsky, W. T. Vetterling, and B. P.
Flannery, "Numerical recipes in C", 2nd ed., Cambridge University 
Press. Pages 896ff.

=head2 Functions

=over

=item crc64 string

Calculate the CRC64 (cyclic redundancy checksum) for B<string>.

In array context, returns two integers equal to the higher and lower
32 bits of the CRC64. In scalar context, returns a 16-character string
containing the CRC64 in hexadecimal format.

=back

=head1 AUTHOR

Alexandre Gattiker, gattiker@isb-sib.ch

=head1 ACKNOWLEDGEMENTS

Based on SPcrc, a C implementation by Christian Iseli, available at 
ftp://ftp.ebi.ac.uk/pub/software/swissprot/Swissknife/old/SPcrc.tar.gz

=cut
