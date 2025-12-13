package SWISS::OHs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::ListBase;
use SWISS::TextFunc;
use SWISS::OH;

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');
  
  %fields = (
	);
}

sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::ListBase;
  
  $self->rebless($class);
  return $self;
}

sub fromText {
  my $self = new(shift);
  my $textRef = shift;
  my $line;
  my @resources;
  
  if ($$textRef =~ /($SWISS::TextFunc::linePattern{OH})/m) {
    foreach $line (split /\n/m, $1) {
      $self->{indentation} += $line =~ s/^ //;
      $line = SWISS::TextFunc->cleanLine($line);
      push @{$self->list()}, SWISS::OH->fromText($line); 
    }
  }
  
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my $newText = '';

  for (@{$self->list()}) {
    $newText .= 'OH   ' . $_->toText . "\n";
  }
  
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{OH});
}

# OXs must never be sorted, overwrite the inherited sort method.
sub sort {
  return 1;
}

1;

__END__

=head1 Name

SWISS::OHs

=head1 Description

B<SWISS::OHs> represents the OH lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
 http://www.expasy.org/sprot/userman.html . The OHs object is a container 
 object which holds a list of SWISS::OH objects. 

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
