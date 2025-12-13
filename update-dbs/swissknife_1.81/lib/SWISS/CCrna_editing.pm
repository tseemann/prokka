package SWISS::CCrna_editing;

use vars qw($AUTOLOAD @ISA %fields);

use Carp;
use strict;
use SWISS::TextFunc;
use SWISS::ListBase;

BEGIN {
  @ISA = ('SWISS::ListBase');
  
  %fields = (
	      term => undef,
	      note => undef,
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
    my $class = shift;
    my $textRef = shift;

    my $self = new SWISS::CCrna_editing;
    my $text = $$textRef;
    $text =~ s/ {2,}/ /g;
    $text =~ s/\s*-!- RNA EDITING:\s*(?:\[(.+)\]:)?\s*//;
    $self->{form}=$1||"";

    $self->initialize();
    if ($text =~ /\bModified_positions=(.*?)(;|\.?$)/) {
        for my $pos (split /, (?!ECO:\d)/, $1) { # p.s. do not split inside ev (new style only) tags
            my $ev = $pos =~ s/($SWISS::TextFunc::evidencePattern)// ? $1 : undef;
            if ($pos =~ /^[A-Za-z]/) { $self->{term} = $pos; }
            else {  $self->add([$pos, $ev]); }
        }
    }
    if ( $text =~ /\bNote=(.+)/ ) {
        ( my $note = $1 ) =~ s/[;.]$//;
        $self->{note} = SWISS::CC::parse2Blocks( $note );
    }
    $self->sort();
    $self->{_dirty} = 0;
    return $self;
}


sub sort { # sort by positions (only used by fromText)
    my ( $self ) = @_;
    $self->set( sort { $a->[0] <=> $b->[0] } @{$self->list} );
}


sub toString {
  my $self = shift;

  my $form = $self->{ form };
  my $text = "CC   -!- RNA EDITING: ";
  $text .= '['. $form . ']: ' if $form;
  $text .= $self->comment( "true" ) . ";";

  return SWISS::TextFunc->wrapOn('',"CC       ", $SWISS::TextFunc::lineLength, $text);
}


sub topic {
  return "RNA EDITING";
}


sub form {
  my $self = shift;
  return $self->{ form };
}


sub comment {
  my ( $self, $with_ev ) = @_;
  my $text = "Modified_positions=";
  if ($self->size) {
    $text .= join ", ", map {
      my ($pos, $ev) = @$_;
      $pos .= $ev if defined $ev && $with_ev;
      $pos;
    } @{$self->{list}};
  }
  else {
    $text .= $self->{term} || "Undetermined";
  }
  if (defined $self->{note} and length $self->{note}) {
    $text .= "; Note=" . SWISS::CC::blocks2String( $self->{note} );
  }
  $text;
}

1;

__END__

=head1 Name

SWISS::CCrna_editing

=head1 Description

B<SWISS::CCrna_editing> represents a comment on the topic 'RNA EDITING'
within a Swiss-Prot or TrEMBL entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .  Comments on other topics are stored
in other types of objects, such as SWISS::CC (see SWISS::CCs for more information).

Collectively, comments of all types are stored within a SWISS::CCs container
object.

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item topic

The topic of this comment ('RNA EDITING').

=item form

The protein form concerned by this comment (undef/empty = canonical/displayed form OR unknown

=item note

The Note of this comment, if any. An array of [ sentence, evidence_tags ]

=item term

A string such as "Undetermined" or "Not_applicable", if any.

=item elements

An array of [position, evidence_tags], if any.

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
