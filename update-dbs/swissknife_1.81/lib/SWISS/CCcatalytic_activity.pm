package SWISS::CCcatalytic_activity;

use vars qw($AUTOLOAD @ISA %fields);

use Carp;
use strict;
use SWISS::TextFunc;
use SWISS::BaseClass;
use SWISS::CC;


BEGIN {
    @ISA = ( 'SWISS::BaseClass' );

    %fields = (
        activity   => undef, # {  rhea => "", ec => "", reaction => "", participants => [], ev => "" }
        directions => undef, # [ { txt => "", rhea => "", ev => "" } ]
        form       => undef,
        _old       => undef  # [ [ txt, ev ], ]
    );
}


sub new {
    my $ref   = shift;
    my $class = ref($ref) || $ref;
    my $self  = new SWISS::BaseClass;
    $self->rebless($class);
    return $self;
}


sub fromText {
    my $class   = shift;
    my $textRef = shift;
    my $self    = new SWISS::CCcatalytic_activity;

    my $text    = $$textRef;
    $self->initialize();

    $text =~ s/ {2,}/ /g;
    $text =~ s/ *-!- CATALYTIC ACTIVITY:\s*(?:\[(.+)\]:)?\s*//;
    $self->{form}=$1||"";

    if ( $text =~ /Reaction=/ ) { # new format (rhea/ec & reaction)
        my $core = {}; my $iscore = 0;
        foreach my $elem ( split /; /, $text ) {
            $elem =~ s/;$//;
            my ( $key, $val ) = ( "", "" );
            ( $key, $val ) = $elem =~ /^(\w+)=(.+)$/;
            if ( $key eq "Reaction" ) {
                $iscore = 1;
                $core->{reaction} = $val;
            }
            elsif ( $key eq "Xref" ) {
                my @ids = split /, /, $val;
                ( my $rhea_id = shift @ids ) =~ s/^Rhea://;
                if ( $iscore ) { # core (reaction)
                    $core->{rhea} = $rhea_id;
                    $core->{participants} = \@ids;
                }
                else           { # direction
                    my $dir = $self->{ directions }->[ -1 ] || { 'txt' => undef, 'ev' => undef };
                    $dir->{rhea} = $rhea_id;
                }
            }
            elsif ( $key eq "EC" ) {
                $core->{ec} = $val;
            }
            elsif ( $key eq "Evidence" ) {
                if ( $iscore ) { $core->{ev} = $val } # core (reaction)
                else           { # direction
                    my $dir = $self->{ directions }->[ -1 ] || { 'txt' => undef, 'rhea' => undef };
                    $dir->{ev} = $val;
                }
            }
            elsif ( $key eq "PhysiologicalDirection" ) {
                $iscore = 0;
                push @{ $self->{directions} }, { 'txt' => $val, 'rhea' => undef, 'ev' => undef };
            }
        }
        $self->{activity} = $core;
    }
    else { # old unstructured format
        my $has_new_style_ev = $text =~ /ECO:/;
        $self->{_old} = SWISS::CC::parse2Blocks( $text );
        # set evidenceTags 4 compatibility with existing ...EvidenceTag methods in BaseClass! + old tests (fixme: clean/remove that mess!?)
        # but the real evidences are now within blocks (2nd field of block array)
        my @evs = map { split /, ?/, $_->[1] } grep { $_->[1] } @{ $self->{_old} };
        my $ev  = $has_new_style_ev ? " {" . join( ", ", @evs ) . "}" : "{" . join( ",", @evs ) . "}";
        $self->evidenceTags( $ev ) if @evs;
    }

    $self->{ _dirty } = 0;
    return $self;
}


sub topic {
    return "CATALYTIC ACTIVITY";
}


sub activity_rhea { # get (or set) rhea (id without "Rhea:" prefix, but with RHEA:) e.g. (RHEA:18037)
    my ( $self, $value, $ev ) = @_;

    if ( !$self->{_old} ) { # only works with new (rhea/ec + reaction) format
        if ( defined $value ) {
            my $new_ev = $ev ? $ev : $self->{ activity }->{ev};
            $self->{activity}->{rhea} = $value;
            $self->{activity}->{ev}   = $new_ev;
        }

        return $self->{activity} ? $self->{activity}->{rhea} : "";
    }
    else { return "" }
}

sub activity_reaction { # get (or set) reaction
    my ( $self, $value, $ev_only_for_old_format ) = @_;

    if ( !$self->{_old} ) { # new (rhea/ec + reaction) format
        if ( defined $value ) {
            $self->{activity}->{reaction} = $value;
        }

        return $self->{activity} ? $self->{activity}->{reaction} : "";
    }
    else { # old format
        if ( defined $value ) {
            my $new_ev = $ev_only_for_old_format ? $ev_only_for_old_format : " {" . join( ", ", map { split /, ?/, $_->[1] } grep { $_->[1] } @{ $self->{_old} } ) . "}";
            $self->evidenceTags( $new_ev );
            $self->{_old} = [ [ $value, $new_ev ] ];
        } # -> ! not tested
        return join( ". ", map { $_->[0] } @{ $self->{_old} } )."."
    }
}

sub activity_ec { # get (or set) ec
    my ( $self, $value, $ev ) = @_;

    if ( !$self->{_old} ) { # only works with new (rhea/ec + reaction) format
        if ( defined $value ) {
            my $new_ev = $ev ? $ev : $self->{ activity }->{ev};
            $self->{activity}->{ec} = $value;
            $self->{activity}->{ev} = $new_ev;
        }

        return $self->{activity} ? $self->{activity}->{ec} : "";
    }
    else { return "" }
}

sub activity_participant {
    my ( $self, $values ) = @_;

    if ( !$self->{_old} ) { # only works with new (rhea/ec + reaction) format
        if (defined $values) {
            $self->{activity}->{participants} = $values;
        }
        return $self->{activity} ? $self->{activity}->{participants} : [];
    }
    else { return [] }
}

sub directions { # get (or set) direction(s) structures
    my ( $self, $values ) = @_;

    if ( !$self->{_old} ) { # only works with new (rhea/ec + reaction) format
        if ( defined $values && ref $values eq "ARRAY") {
            $self->{directions} = $values;
        }
        return $self->{directions};
    }
    else { return [] }
}


sub toString {
    my ( $self ) = @_;

    my $form = $self->{ form };

    my $activity_txt = $self->_activity_to_text();

    my $text = "CC   -!- CATALYTIC ACTIVITY:";
    $text .= ' ['. $form . ']:' if $form;
    if ( !$self->{_old} ) { # new (rhea/ec, reaction) format
        #my $form = $self->{form} ? " $self->{form}:" : "";
        $text .= "\n";
        $text .= SWISS::TextFunc->wrapOn( 'CC       ',"CC         ", $SWISS::TextFunc::lineLength, $activity_txt );
        map {
            my $direction_txt = _direction_struct_to_text( $_ );
            $text .= SWISS::TextFunc->wrapOn( 'CC       ',"CC         ", $SWISS::TextFunc::lineLength, $direction_txt );
        } @{ $self->{directions} };
    }
    else { # old unstructured format
        $text .= " ".$activity_txt;
        $text = SWISS::TextFunc->wrapOn('',"CC       ", $SWISS::TextFunc::lineLength, $text );
    }

    return $text;
}

sub _activity_to_text {
    my ( $self, $no_ev ) = @_;
    if ( !$self->{_old} ) { # new structured format
        my $activity     = $self->{ activity };
        my $activity_txt = "Reaction=$activity->{reaction};";
        if ( $activity->{rhea} ) {
            $activity_txt .= " Xref=Rhea:$activity->{rhea}";
            if ( $activity->{participants} )  { $activity_txt .= ", " . join( ", ", @{ $activity->{participants} } ) }
            $activity_txt .= ";";
        }
        if ( $activity->{ec} )            { $activity_txt .= " EC=$activity->{ec};" }
        if ( $activity->{ev} && !$no_ev ) { $activity_txt .= " Evidence=$activity->{ev};" }
        return $activity_txt;
    }
    else { # old format
        return ( $no_ev ? join( ". ", map { $_->[0] } @{ $self->{_old} } )."." : SWISS::CC::blocks2String( $self->{_old}, $self->evidenceTags )."." );
    }
}
sub _direction_struct_to_text {
    my ( $direction, $no_ev ) = @_;
    my $direction_txt = "";
    if ( $direction->{txt} )           { $direction_txt .= "PhysiologicalDirection=$direction->{txt};" }
    if ( $direction->{rhea} )          { $direction_txt .= " Xref=Rhea:$direction->{rhea};" }
    if ( $direction->{ev} && !$no_ev ) { $direction_txt .= " Evidence=$direction->{ev};" }
    return $direction_txt;
}


sub form {
    my $self = shift;
    return $self->{ form };
}


sub comment { # unwrapped content (without ev)
    my ($self, $with_ev) = @_;

    my $activity_txt  = $self->_activity_to_text (  "no_ev=true" );
    my $direction_txt = "";
    map { $direction_txt .= ( $direction_txt ? " " : "" ) . _direction_struct_to_text( $_ , "no_ev=true" ); } @{ $self->{directions} };
    return $activity_txt . ( $direction_txt ? " $direction_txt" : "" );
}


#sub sort {
#    my $self = shift;
#    $self->{ list } = sort { lc( $a->[0] ) cmp lc( $b->[0] ) } @{ $self->{ list } };
#}


1;

__END__

=head1 Name

SWISS::CCcatalytic_activity

=head1 Description

B<SWISS::CCcofactor> represents a comment on the topic 'CATALYTIC ACTIVITY'
within a Swiss-Prot or TrEMBL entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .  Comments on other topics are stored
in other types of objects, such as SWISS::CC (see SWISS::CCs for more information).

Collectively, comments of all types are stored within a SWISS::CCs container
object.

=head1 Inherits from

SWISS::BaseClass

=head1 Attributes

=over

=item topic

The topic of this comment ('CATALYTIC ACTIVITY').

=item form

The protein form concerned by this comment (undef/empty = canonical/displayed form OR unknown)

=item comment

The "text" version of this comment (without evidences and new lines).

=back
=head1 Methods

=over

=item activity_rhea

The rhea id (e.g. RHEA:18037) of the reaction (only for new structured CC CATALYTIC ACTIVITY)

=item activity_rhea( $new_rhea_id, $new_optional_reaction_ev )

Set rhea activity to $new_rhea_id (and reaction ev to $new_optional_reaction_ev if provided)
(only for new structured CC CATALYTIC ACTIVITY)

=item activity_reaction

The reaction txt (e.g. agmatine + H2O = N-carbamoylputrescine + NH4(+))

=item activity_reaction( $new_reaction_txt )

Set reaction txt to $new_reaction_txt
(on old unstructured format: extra $ev could be added)

=item activity_ec

The reaction EC (e.g. 3.5.3.12)

=item activity_ec( $new_reaction_ec, , $new_optional_reaction_ev )

Set reaction EC to $new_reaction_ec (and reaction ev to $new_optional_reaction_ev if provided)
(only for new structured CC CATALYTIC ACTIVITY)

=item activity_participant

The reaction participants as a String Array (e.g. [ "ChEBI:CHEBI:15377", "ChEBI:CHEBI:28938", "ChEBI:CHEBI:58145", "ChEBI:CHEBI:58318" ])
(participant are shown as dbtype:id e.g. in "ChEBI:CHEBI:15377" CheBI is db type, CHEBI:15377 is (CheBi) id)
(only for new structured CC CATALYTIC ACTIVITY)

=item activity_participant( $new_participant_array )

Set reaction participants to $new_participant_array (array of strings)
(only for new structured CC CATALYTIC ACTIVITY)


=item directions

The directions: Array of direction structures as hash e.g. [ { 'txt' => 'left-to-right', 'rhea' => 'RHEA:16846', 'ev' => '{ECO:0000269|PubMed:29420286}' } ]
p.s. in well formed UniProtKB data 'txt' will be 'right-to-left' or 'left-to-right' (in that order); there should be no more than 2 directions (minimum: 0)

=item direction( $new_directions )

Set directions Array to $new_directions ...
(only for new structured CC CATALYTIC ACTIVITY)

=back
=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
