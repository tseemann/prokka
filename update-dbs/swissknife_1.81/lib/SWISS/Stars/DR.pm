package SWISS::Stars::DR;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;


BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase' );
  
  %fields = ( );
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

  foreach $line ($$textRef =~ /^(\*\*DR .*\n)/gm) {
    $line = SWISS::TextFunc->cleanLine($line);
    $self->add($line);
  } # p.s. PROSITE; PS..." lines are not handled (not considered as **DR)! (they should disappear anyway)

  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my $newText = '';

  my $sep = ' ';
  my $len = $SWISS::TextFunc::lineLengthStar;

  # assemble new text
  if ($self->size > 0) {
    map ({$newText .= SWISS::TextFunc->wrapOn("\*\*DR ", 
					      "\*\*DR ",
					      $len,
					      $_,
					      $sep)} 
	 $self->elements);
  };

  # insert new text
  SWISS::Stars::insertLineGroup($self, $textRef, $newText, "DR");

  # now the object is clean
  $self->{_dirty} = 0;

  return 1;
}

# sort **DR alphab.
sub sort {
  my $self = shift;
  return $self->set( sort { (my $i=$a)=~s/; / /g; (my $j=$b)=~s/; / /g; lc($i) cmp lc($j) } @{$self->list}); # p.s. set sets _dirty = 1
};


1;

__END__

=head1 Name

SWISS::default

=head1 Description

B<SWISS/Stars/DR.pm> is the class to represent DR information in the "annotator's section" (internal section) within an SWISS-PROT + TrEMBL
entry. The "annotator's section" is not visible to the public. The structured part has line tags of the form '**xx'. See also the general description in Stars.html.   


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
