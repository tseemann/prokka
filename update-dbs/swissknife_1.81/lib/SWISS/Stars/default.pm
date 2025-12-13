package SWISS::Stars::default;

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
  my $tag = shift;

  my $line;
  
  foreach $line ($$textRef =~ /^(\*\*$tag .*\n)/gm) {
    $line = SWISS::TextFunc->cleanLine($line);
    $self->add($line);
  }

  # we have only read, so the object is still clean
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my ($textRef, $tag) = @_;
  my $newText = '';

    my $sep = ' ';
    my $len = $SWISS::TextFunc::lineLengthStar;
    if ($tag =~ /^(?:ZA|ZB|ZC)$/) { 
        $sep = '; ';
        $len = 80;
    }
  # assemble new text
  if ($self->size > 0) {
    map ({$newText .= SWISS::TextFunc->wrapOn("\*\*$tag ", 
					      "\*\*$tag ",
					      $len,
					      $_,
					      $sep)} 
	 $self->elements);
  };

  # insert new text
  SWISS::Stars::insertLineGroup($self, $textRef, $newText, $tag);

  # now the object is clean
  $self->{_dirty} = 0;

  return 1;
}

# No sorting by default.
sub sort {
  return 1;
};


1;

__END__

=head1 Name

SWISS::default

=head1 Description

B<SWISS/Stars/default.pm> is the default class to represent structured information in the "annotator's section" within an SWISS-PROT + TrEMBL
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
