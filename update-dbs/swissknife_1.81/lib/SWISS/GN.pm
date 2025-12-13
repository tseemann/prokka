package SWISS::GN;

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
	     text => undef
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
  $self->text($text);
  return $self;
}

sub toText {
  my $self = shift;

  return $self->text . $self->getEvidenceTagsString;
}


#Convert gene names to mixed case, according to one or more regular
#expressions. This is done by changing the letters in the ORF name to
#lowercase in all possible combinations until one is found which matches one of
#the regular expressions given as parameters.
sub toMixedCase {
	my ($self, @regexps) = @_;
	my $orfname = SWISS::TextFunc::toMixedCase($self->text, @regexps);
	$self->text($orfname);
	return $orfname;
}

1;

__END__

=head1 Name

SWISS::GN.pm

=head1 Description

B<SWISS::GN> represents one gene name from the GN line.
The container object for several synonym gene names is 
SWISS::GeneGroup.

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<text>

One gene name.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head2 Reading/Writing methods

=over

=item toMixedCase(@regexps)

Convert gene names to mixed case, according to one or more regular expressions.
This is typically useful for converting uppercase ORF numbers to mixed case.
E.g. the E.coli gene "B1563" converted with the regexp '(b(\d{4}(\.\d)?))' will
yield the gene name "b1563". The method also supports fused gene names, e.g.
"B0690/B0691" is converted to "b0690/b0691". The method changes the text of the
SWISS::GN object and also returns the new text value.

=back
