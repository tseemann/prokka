package SWISS::OH;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::BaseClass;


BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass');
  
  %fields = (
    NCBI_TaxID => undef,
	  text => undef,
	);
}

sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::BaseClass;
  
  $self->rebless($class);
  return $self;
}

sub fromText {
  my $self = new(shift);

  my $text = shift;

  # Parse out the evidence tags
  if ($text =~ s/($SWISS::TextFunc::evidencePattern)//) {
    my $tmp = $1;
    $self->evidenceTags($tmp);
  }
  
  if ($text =~ /^NCBI_TaxID=(\d+); (.+)\.$/) {
    $self->{NCBI_TaxID} = $1;
	  $text = $2;
  }
  
  $self->text($text);

  return $self;
}

sub toText {
  my $self = shift;
  my $text = '';
  return 'NCBI_TaxID=' . $self->NCBI_TaxID . '; ' 
		. $self->text . '.' . $self->getEvidenceTagsString;
}

1;

__END__

=head1 Name

SWISS::OH

=head1 Description

B<SWISS::OH> represents one taxon from the OH line. The container object is SWISS::OHs.


=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<NCBI_TaxID>

Tax ID.

=item C<text>

Name, common name and synonym of the organism.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
