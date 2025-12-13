package SWISS::Stars::aa;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;


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

  # The tag for the aa section is '  '
  foreach $line ($$textRef =~ /^(\*\*   .*\n)/gm) {
    $line = SWISS::TextFunc->cleanLine($line);
    $self->add($line);
  };

  # we have only read, so the object is still clean
  $self->{_dirty} = 0;

  return $self;
}

sub toText {
  my $self = shift;
  my ($textRef) = @_;
  my $newText = '';
  my $tag = '  ';

  # remove old aa lines
  $$textRef =~ s/^(\*\*$tag .*\n)//gm;

  # assemble new aa lines  
  map ({$newText .= SWISS::TextFunc->wrapOn("\*\*$tag ", 
					    "\*\*$tag ",
					    $SWISS::TextFunc::lineLengthStar,
					    $_,
					    ' ')} 
       $self->elements);

  # now the object is clean
  $self->{_dirty} = 0;

  # add new aa lines at the beginning
  return $$textRef = $newText . $$textRef;
}

# The aa section should never be sorted
sub sort {
  return 1;
};


1;

__END__

=head1 Name

SWISS::aa.pm

=head1 Description

B<SWISS/Stars/aa.pm> represents the unstructured part of the "annotator's section" (source section) within an SWISS-PROT + TrEMBL
entry. The "annotator's section" is not visible to the public. The unstructured part of it has the line tag '**  '. See also the general description in Stars.html.   


=head1 Inherits from
SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>
Each line is stored as one element of the list.

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
