package SWISS::OGs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::OG;

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

sub initialize {
}

sub fromText {
  my $self = new(shift);
  
  my $textRef = shift;
  my $line    = "";
  my @tmp;

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'OG'})/m){ 
    $line = join ' ', map {
      $self->{indentation} += s/^ //;
      SWISS::TextFunc->cleanLine($_);
    } (split /\n/m, $1 );  
    # drop 'AND'
    $line =~ s/\s*,\s*(AND\s+)*/, /gi;
    
    
    # Step one: Split on dots separating organelle classes (Plasmid, Mitochondrion).

    # complex expression for separator to make sure commas within brackets are
    # not regarded as separators.
    @tmp = SWISS::TextFunc->listFromText($line, '\.\s+', '\.');

    # Step two: Split on commas separating elements of organelle classes.
    my @resultList;
    foreach my $organelle (@tmp) {
      push @resultList, SWISS::TextFunc->listFromText($organelle, ',\s+(?![^\(\{]+[\)\}])', '\.');
    }

    @resultList = map {SWISS::OG->fromText($_)} @resultList;

    push (@{$self->list()}, @resultList); 
    
  }
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my (@tmp, @lines);
  my (@plasmids, @nonPlasmids);
  my $nonPlasmidText = '';
  my $plasmidText = '';

  @tmp = $self->elements();

  foreach my $element (@tmp) {
    if ($element->isPlasmid()) {
      push @plasmids, $element;
    } else {
      push @nonPlasmids, $element;
    }
  }

  # First format all non-plasmid elements
  foreach my $nonPlasmid (@nonPlasmids) {
    my $indent = $self->{indentation} ? " " : "";
    $nonPlasmidText .= "${indent}OG   " . $nonPlasmid->toText() . ".\n";
  }

  # Format plasmids
  if ($#plasmids > -1) {
    # insert an 'AND' before the last species if appropriate
    @tmp = map {$_->toText} @plasmids;
    if ($#tmp > 0) {
      push(@tmp, 'and '. pop(@tmp));
    }
    
    $plasmidText = join(", ", @tmp);
    
    $plasmidText .= ".";
    
    my $prefix = "OG   ";
    my $col = $SWISS::TextFunc::lineLength;
    $col++, $prefix=" $prefix" if $self->{indentation};
    $plasmidText = SWISS::TextFunc->wrapOn($prefix, $prefix, $col,
				       $plasmidText, 
				       ',\s+and\s+', ',\s+', '(?=\()', '\s+');
  };
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, 
                                          $nonPlasmidText . $plasmidText, 
					  $SWISS::TextFunc::linePattern{'OG'});
}

# OGs must never be sorted, overwrite the inherited sort method.
sub sort {
  return 1;
}

1;

__END__

=head1 Name

SWISS::OGs

=head1 Description

B<SWISS::OGs> represents the OG lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
 http://www.expasy.org/sprot/userman.html . The OGs object is a container object which holds a list of SWISS::OG objects.

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

  Each list element is a SWISS::OG object.

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
