package SWISS::CCseq_caution;

use vars qw($AUTOLOAD @ISA);

use Carp;
use strict;
use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::BaseClass;

BEGIN {
  @ISA = ('SWISS::ListBase');
}

sub new {
    my $ref = shift;
    my $class = ref($ref) || $ref;
    my $self = new SWISS::ListBase;
    $self->rebless($class);
    return $self;
}

sub fromText {
    my $class   = shift;
    my $textRef = shift;

    my $self = new SWISS::CCseq_caution;
    my $text = $$textRef;
    $self->initialize();

    $text =~ s/ +/ /g;
    $text =~ s/\s*-!- SEQUENCE CAUTION:\s*(?:\[(.+)\]:)?\s*//;
    $self->{form}=$1||"";

    while ( length $text ) {
        if ( $text =~ s/^\s*Sequence=(.*?); Type=(.*?);(?: Positions=(.*?);)?(?: Note=(.*?);)?(?: Evidence=(.+?);)?(?:\s*|\Z)//s ) {
            my ($sequence, $type, $positions, $note, $new_style_evidence, $old_style_evidence) = ($1, $2, $3, $4, $5);
            my $arg = new SWISS::BaseClass;
            if ( $old_style_evidence && $old_style_evidence =~ /($SWISS::TextFunc::evidencePattern)/m ) {
  	            my $quotedEvidence = quotemeta $&;
  	            $sequence =~ s/$quotedEvidence//m;
            }
            $arg->{'sequence'}  = $sequence;
            $arg->{'type'}      = $type;
            $arg->{'positions'} = $positions if defined $positions;
            $arg->{'note'}      = $note if defined $note;
            $arg->{'evidence'}  = $new_style_evidence if defined $new_style_evidence;
            $arg->evidenceTags( $old_style_evidence ) if $old_style_evidence;
            $self->push($arg);
        }
        else { # dangling text
            carp "CC SEQUENCE CAUTION parse error, ignoring $text";
            last;
        }
    }
    $self->sort;
    $self->{_dirty} = 0;
    return $self;
}


sub sort {
    my $self = shift;

    if ($self) {
        my @items;
        for my $item ($self->elements) {
            push @items, $item
        }
        $self->set(sort {
              lc $a->{sequence} cmp lc $b->{sequence} || $a->{type} cmp $b->{type}
        } @items );
    }
}


sub toString {
    my $self = shift;

    my $form = $self->{ form };
    my $text = "-!- SEQUENCE CAUTION:";
    $text .= ' ['. $form . ']:' if $form;
    $text .= "\n".$self->comment;
    $text =~ s/^/CC       /mg;
    $text =~ s/    //;

    return $text;
}


sub topic {
    return "SEQUENCE CAUTION";
}


sub form {
  my $self = shift;
  return $self->{ form };
}


sub comment {
    my ($self) = @_;
    my $text = '';
    if ($self) {
        for my $el ($self->elements) {
            $text .= 'Sequence=' . $el->{sequence} . $el->getEvidenceTagsString();
            $text .= '; Type=' . $el->{type};
            $text .= '; Positions=' . $el->{positions} if $el->{positions};
            $text .= '; Note=' . $el->{note} if $el->{note};
            $text .= '; Evidence=' . $el->{evidence} if $el->{evidence};
            $text .= ";\n";
        }
    }
    $text;
}

1;

__END__

=head1 Name

SWISS::CCinteraction

=head1 Description

B<SWISS::CCinteraction> represents a comment on the topic 'INTERACTION'
within a Swiss-Prot or TrEMBL entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .  Comments on other topics are stored
in other types of objects, such as SWISS::CC (see SWISS::CCs for more information).

Collectively, comments of all types are stored within a SWISS::CCs container
object.

Each element of the list is a hash with the following keys:

  accession
  identifier
  xeno
  NbExp
  IntAct      (array reference)

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item topic

The topic of this comment ('SEQUENCE CAUTION').

=item form

The protein form concerned by this comment (undef/empty = canonical/displayed form OR unknown

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
