package SWISS::CCcofactor;

use vars qw($AUTOLOAD @ISA %fields);

use Carp;
use strict;
use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::CC;


BEGIN {
  @ISA = ( 'SWISS::ListBase' );
  
  %fields = (
          form        => undef,  
	      note        => undef, # [ txt, ev ]
	      note_blocks => undef # [ [txt, ev ] ]
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
    my $self = new SWISS::CCcofactor;
    my $text = $$textRef;
    $self->initialize();
  
    $text =~ s/ *-!- COFACTOR: +//;
    $text =~ s/; {2,}/; /g;
    $text =~ s/, {2,}/, /g;
    
    if ( $text !~ /Name=/ && $text !~ /Note=/ ) { # old format!
    	  my $note = $text;
    	( my $note_ev = $1 ) if $note =~ s/($SWISS::TextFunc::evidencePattern)\.?//;
    	$self->{ note } = [ $note.".", $note_ev ] if $note;
    }
    else { # new format
        my $form = $text =~ s/^([^:]+): (?=N)// ? $1 : "";
        $self->{ has_old_form } = $form =~ /^\[/ ? 0 : 1;
           $form =~ s/^\[|\]$//g;
        $self->{ form }  = $form if $form;

        my $note = $text =~ s/ ?Note=(.+)$// ? $1 : "";
           $note =~ s/;$//;
        $self->{ form }  = $form if $form;
        $self->{ note_blocks } = SWISS::CC::parse2Blocks( $note ) if $note; #[ $note, $note_ev ] if $note;
        foreach my $name ( split / +(?=Name=)/, $text ) {
            my $ev = $name =~ s/ +Evidence=($SWISS::TextFunc::evidencePattern);// ? " ".$1 : undef;
            $self->add( [ $name, $ev ] );
        } # $name = e.g. "Name=[2Fe-2S] cluster; Xref=ChEBI:CHEBI:49601;" includes chebi xref! not further parsed!
    }

    $self->{_dirty} = 0;
    return $self;
}


sub topic {
	return "COFACTOR";
}


sub form {
    my $self = shift;
    return $self->{ form };
}


sub toString {
    my ( $self ) = @_;

    my $form = "";
    if ( $self->{form} ) {
        if ( $self->{has_old_form} ) { $form = ' '.$self->{form}.':'; }
        else                         { $form = ' ['.$self->{form}.']:'; }
    }
    my $text = "CC   -!- COFACTOR:$form\n";
    
    foreach my $name_ev ( @{ $self->{list} } ) {
        my ( $name, $ev ) = @$name_ev;
        my   $line = $name;
        if ( $ev ) { $ev=~s/^ +//; $line .= " Evidence=".$ev.";" }
        $text .= SWISS::TextFunc->wrapOn( 'CC       ',"CC         ", $SWISS::TextFunc::lineLength, $line, "(?<=;) ", "(?<=,) ", $SWISS::TextFunc::textWrapPattern1 );
    }
    if ( $self->{note} ) { # old format
     	my ( $note, $note_ev ) = @{ $self->{ note } };
        $note_ev ||= "";
        $note      = "Note=" . $note . $note_ev . ";";
        $text     .= SWISS::TextFunc->wrapOn( 'CC       ',"CC       ", $SWISS::TextFunc::lineLength, $note );
    }
    if ( $self->{note_blocks} ) {
        my $note  = "Note=" . SWISS::CC::blocks2String( $self->{ note_blocks }, "" ) . ";";
        $text    .= SWISS::TextFunc->wrapOn( 'CC       ',"CC       ", $SWISS::TextFunc::lineLength, $note );
    }
    
    return $text; 
}


sub comment {
    my ( $self, $with_ev ) = @_;
    
    my $text = "";
    foreach my $name_ev ( @{ $self->{list} } ) {
        my ( $name, $ev ) = @$name_ev;
        $text .= ( $text ? " " : "" ) . $name;
        if ( $ev && $with_ev ) { $ev=~s/^ +//; $text .= " Evidence=".$ev.";" }
    }
    if ( $self->{ note } ) {
    	my ( $note, $note_ev ) = @{ $self->{ note } };
    	$note_ev = "" unless $with_ev && $note_ev;
        $note      = "Note=" . $note . $note_ev . ";";
        $text .= ( $text ? " " : "" ) . $note;
    }
    
    return $text;
}


sub structured_names {
    my ( $self, $values ) = @_;

    if ( defined $values ) { # set
        $self->{list} = \ map { [ "Name=".$_->{name}."; Xref=ChEBI:".$_->{chebi}, $_->{ev} ] } @{ $values };
    }
    my @out = map { # get
        my $elem = {};
        $elem->{ev} = $_->[1];                                    # e.g. ECO:0000255|HAMAP-Rule:MF_01841
        my @vals = grep { $_ ne '' } split /Name=|Xref=/, $_->[0];
        ( $elem->{name}  = $vals[0] || "" ) =~ s/; ?$//;          # e.g. FAD
        ( $elem->{chebi} = $vals[1] || "" ) =~ s/^ChEBI:|; ?$//g; # e.g. CHEBI:57692
        print "----STRUCT COF-->[".$elem->{name}."]\n";
        $elem;
    } @{ $self->{list} };
    return \@out;
} # returns Array of { name->..., chebi->..., ev->... }


#sub sort {
#    my $self = shift;
#    $self->{ list } = sort { lc( $a->[0] ) cmp lc( $b->[0] ) } @{ $self->{ list } };
#}


1;

__END__

=head1 Name

SWISS::CCcofactor

=head1 Description

B<SWISS::CCcofactor> represents a comment on the topic 'COFACTOR'
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

The topic of this comment ('COFACTOR').

=item form

The protein form concerned by this comment (undef/empty = canonical/displayed form OR unknown)

=item comment

The "text" version of this comment (without evidences and new lines).

=item note

The note and evidence (Note= in new format or full description in old format)
reference to an array of [ $note, $note_ev ] (strings)

=item elements

An array of [name_str, evidence_tags_str], if any.

=back
=head1 Methods

=over

=item structured_names

(only for new structured CC COFACTOR)
The names as array of 'name' txt, 'chebi' id, 'ev' string (hash) structures
e.g. [ { 'name'->'FAD', 'chebi'->'CHEBI:57692', 'ev'->'ECO:0000250' } ]

=item structured_names( $new_values )

(only for new structured CC COFACTOR)
Set names with array of 'name' txt, 'chebi' id, 'ev' string (hash) structures like returned by get-er version


=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
