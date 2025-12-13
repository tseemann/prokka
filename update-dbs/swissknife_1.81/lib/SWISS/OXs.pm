package SWISS::OXs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::ListBase;
use SWISS::TextFunc;
use SWISS::OX;

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass');

  # All possible taxonomic resources need to be listed here.
  %fields = ('NCBI_TaxID' => undef,
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
  my $self = shift;
  $self->NCBI_TaxID(new SWISS::ListBase);
}

sub fromText {
    # Line format of the OX line is
    # NCBI_TaxID=126566, 38, 846, 23412;
    my $self = new(shift);
  
    my $textRef = shift;
    my $line    = "";
    my @resources;
 
    if ($$textRef =~ /($SWISS::TextFunc::linePattern{'OX'})/m) { 
        $line = join ' ', map {
            $self->{indentation} += s/^ //;
            SWISS::TextFunc->cleanLine($_)
        } (split /\n/m, $1 );

        # split into different Taxonomic_resource name blocks
        @resources = split /\;\s*/, $line;
        foreach my $resource (@resources) {
            my ($resourceName, $taxids);
            if (($resourceName, $taxids) = $resource =~ /(\w+)\=(.*)/) {
	           unless (defined $resourceName) {
	               warn ("$resourceName is not a legal taxonomic resource identifier. Skipping \n$line!");
	               next;
	           }
	
	           # crete objects for the individual tax ids
	           $self->$resourceName()->add(map {SWISS::OX->fromText($_)} split( /\, (?!ECO:\d)/, $taxids ) );
            }
            else {
	           warn ("Parse error in OX line $line");
            }
        }
    }
    
    $self->{_dirty} = 0;
    return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my @tmp;
  my $newText = '';

  if ($self->NCBI_TaxID()->size > 0) {
    @tmp = map {$_->toText} $self->NCBI_TaxID->elements();

    $newText = "NCBI_TaxID\=". join(", ", @tmp) . "\;";
    
    my $prefix = "OX   ";
    my $col = $SWISS::TextFunc::lineLengthStar;
    $col++, $prefix=" $prefix" if $self->{indentation};
    $newText = SWISS::TextFunc->wrapOn($prefix, $prefix, $col,
				       $newText, ", ",
				      );
  };
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'OX'});
}

# OXs must never be sorted, overwrite the inherited sort method.
sub sort {
  return 1;
}

1;

__END__

=head1 Name

SWISS::OXs

=head1 Description

B<SWISS::OXs> represents the OX lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
 http://www.expasy.org/sprot/userman.html . The OXs object is a container object which holds a list of SWISS::OX objects for each currently permitted taxonomic resource. 

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<NCBI_TaxID>

  A ListBase object which holds a list of tax ids.

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head1 Example

  $taxid = new SWISS::OX;
  $taxid->text('1234');
  $entry->OXs->NCBI_TaxID()->add($taxid);

  foreach my $taxid ($entry->OXs->NCBI_TaxID()->elements()) {
    print $taxid->text, "\n";
  }
