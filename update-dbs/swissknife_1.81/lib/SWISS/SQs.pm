package SWISS::SQs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields $crcLabel %molWeight);
use Exporter;
use Carp;
use strict;
use SWISS::BaseClass;
use SWISS::TextFunc;
use SWISS::CRC64;

BEGIN {
  @EXPORT_OK = qw();
  @ISA = ( 'Exporter', 'SWISS::BaseClass');
  
  %fields = ( 'seq' => undef,
	      'length' => undef,
	      'molWeight' => undef,
	      'crc' => undef,
	    );

	# integer part, and decimal part * 1e+4 of average (chemical) aa masses
	# [with 4 digits] minus a water molecule [18.0153]
	%molWeight = (
		"A" => [ 71,  788], "C" => [103, 1388], "D" => [115,  886],
		"E" => [129, 1155], "F" => [147, 1766], "G" => [ 57,  519],
		"H" => [137, 1411], "I" => [113, 1594], "K" => [128, 1741],
		"L" => [113, 1594], "M" => [131, 1926], "N" => [114, 1038],
		"P" => [ 97, 1167], "Q" => [128, 1307], "R" => [156, 1875],
		"S" => [ 87,  782], "T" => [101, 1051], "V" => [ 99, 1326],
		"W" => [186, 2132], "Y" => [163, 1760],
		"J" => [113, 1594], #J = I or L
        "U" => [150, 388], # selenocysteine (Sec) 150.0388
        "O" => [237, 3018], # pyrrolysine (Pyl) 237.3018
		#The masses for the degenerate amino acids were computed by weighing them with the
		#amino acid frequencies in Swiss-Prot Release 45.0 of 25 Oct 2004 (total 99.9):
		#A=>7.82, Q=>3.94, L=>9.62, S=>6.87, R=>5.32, E=>6.60, K=>5.93, T=>5.46, N=>4.20, G=>6.94,
		#M=>2.37, W=>1.16, D=>5.30, H=>2.27, F=>4.01, Y=>3.07, C=>1.56, I=>5.90, P=>4.85, V=>6.71,
		"B" => [114, 6532], #B = N or D
		"Z" => [128, 7473], #Z = Q or E
		"X" => [111, 3306], #X = any aa
	);

}

 


sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::BaseClass;
  
  $self->rebless($class);
  return $self;
}

sub initialize {
  my $self = shift;
  
  $self->{'seq'} = '';
  $self->{'length'} = 0;
  $self->{'molWeight'} = 0;
  $self->{'crc'} = 0;
}

# If the sequence is updated, the rest has to be updated, too.
sub seq {
  my $self = shift;
  my $sq = '';
  
  if (@_) {
    $self->{seq} = shift;
    $self->update;
  }
  else {
    return $self->{seq};
  };
}


sub update {
  my $self = shift;
  
  $self->length(length $self->seq);
  $self->molWeight(&calcMolWeight($self->seq));
  $self->crc(scalar SWISS::CRC64::crc64($self->seq()));
  
  $self->{_dirty} = 0;
  
  return 1;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my $sequence = $self->seq();
  my (@tmp, @lines, $newText);

  # update
  if ($self->{_dirty}) {
    $self->update;
  };

  # format SQ line
  $newText = sprintf("SQ   SEQUENCE   %d AA;  %d MW;  %s %s;\n",
		     $self->length,
		     int($self->molWeight+0.5), #true rounding (int() truncates)
		     $self->crc(),
		     'CRC64');
  
  # format the sequence
  $newText 
    = $newText . 
      '     ' . join("\n     ", 
		     map {join " ", ($_ =~ m/.{1,10}/g)} 
		     ($sequence =~ m/.{1,$SWISS::TextFunc::lineLengthSQ}/g)) .
		       "\n";

  $self->{_dirty} = 0;
  
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'SQ'});
}

sub fromText {
  my $self = new(shift);

  my $textRef = shift;
  my ($line, @lines);
  my @tmp;

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'SQ'})/m){
    @lines = split /\n/m, $1;

    # process SQ line
    $line = shift @lines;
    $line = SWISS::TextFunc->cleanLine($line);
    @tmp = SWISS::TextFunc->listFromText($line, ';*\s+', '\.');
    $self->length($tmp[1]);
    $self->molWeight($tmp[3]);
    $self->crc($tmp[5]);
 
    # process the sequence
    $line = join '', @lines;
    # remove spaces
    $line =~ tr/ //d;
    # assign the sequence
    $self->{seq} = $line;
    $self->{_dirty} = 0;
  }
  else {
    $main::opt_warn && $main::opt_warn>1 && carp "No SQ lines in $$textRef";
  };

  $self->{_dirty} = 0;
  return $self;
}

# return the molecular weight of an amino acid chain
sub calcMolWeight{
  my ($string) = @_;
  
  my $mwInt = 18; #1 water molecule = 18.0153 Da
  my $mwFloat = 153; # water mass decimal part * 10^4 (leading zero removed)
  
  foreach my $aa (keys %molWeight){
    my ($int, $float) = @{$molWeight{$aa}};
    my $count = $string =~ s/$aa/$aa/g;
    $mwInt += $count * $int;
    $mwFloat += $count * $float;
  }
 
  return $mwInt + $mwFloat/1e4;
}

1;

__END__

=head1 NAME 

B<SWISS::SQs.pm>

=head1 DESCRIPTION

B<SWISS::SQs> represents the SQ lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<seq>

The amino acid sequence in string representation.

=item C<length>

The sequence length.

=item C<molWeight>

The molecular weight.

=item C<crc>

The CRC checksum of the sequence. This is recalculated using the C<SWISS::CRC64> module. 

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=item update

Should be called if the sequence has been modified.

=back

=head2 Specific methods

=over

=item calcMolWeight string

Calculate the molecular weight for B<string>.

=back
