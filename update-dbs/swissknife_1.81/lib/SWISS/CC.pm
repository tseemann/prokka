package SWISS::CC;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::BaseClass;
use SWISS::TextFunc;


BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass');
  
  %fields = (
	     topic   => undef,
         comment => undef, # comment str (without evs)
         blocks  => undef  # [ [ comment_block_str, ev_str ] ]
	    );
}

sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::BaseClass;
  $self->rebless($class);
  return $self;
}


sub parse2Blocks { 
# class / static method: comment : String -> [ [ String, String ], ... ] 
# parse a (multi) [ block,  block-ev ] comment (free text comment or Note= from structured comments, or even structured txt elems with one ev for "symmetrical" parsing) into array of comment, ev pairs (as array)
    my $comment = shift;
    my @blocks;
    foreach my $elem ( split( $SWISS::TextFunc::evidencePatternAsSep, $comment ) ) { # split on evtag as sep! (includes evtag content in split output)
        if    ( $elem !~ /^ECO:\d+/ )             { push @blocks, [ $elem, "" ] }  # a blocktxt = ~sentence
        elsif ( ref( $blocks[ -1 ] ) eq 'ARRAY' ) { $blocks[ -1 ]->[ 1 ] = $elem } # EV(s) for the blocktxt
        else                                      { push @blocks, [ $elem, "" ]; } # bad should not happen (block has first elem - should be txt - recognized as ev! save it as txt)
    } # one block = e.g. [ "Involved in riboflavin biosynthesis", "ECO:0000269|PubMed:22081402, ECO:0000269|PubMed:23203051" ]
    
    return \@blocks;
} # p.s. a txt without ev will keep its final "." (if present: "." in last sentence is removed by CCs.pm _chooseType) (as evidencePatternAsSep wont eat it) whereas when there is an ev the "." is gone!... (is selfhealing with blocks2String but asymetrical! ? TODO FIXME ?)


sub fromText {  
  
  my $_class  = shift;
  my $textRef = shift;
  my $self    = new SWISS::CC;
  my $text    = $$textRef;
  my ( $topic, $form, $comment );
  
  if ($text ne '') {
  
    # split into topic and comment.
    if ($text =~ /\-\!\-\s+(.*?):\s*(?:\[(.+)\]:)?\s*(.*)$/x ){
      $topic = $1; $form = $2; $comment = $3;
    } else {
      $topic = ''; 
      $comment = $text;
    }

    my $has_new_style_ev = $comment =~ /ECO:/;

    # Parse
    if ( $topic ne "MASS SPECTROMETRY" ) { # free text comment
        $self->{ blocks } = parse2Blocks( $comment );
    }
    else { # TODO? create module for mass spec: CCmass_spec.pm to model individual fields! here just a big txt blob!...
        my $evs = "";
        $evs = $1 if $comment =~ s/ Evidence=\{(.+)\}[;.]?\s*$/ Evidence=/;
        $self->{ blocks } = [ [ $comment, $evs ] ];
    }

    # set evidenceTags 4 compatibility with existing ...EvidenceTag methods in BaseClass! + old tests (fixme: clean/remove that mess!?)
    # but the real evidences are now within blocks (2nd field of block array)
    my @evs = map { split /, ?/, $_->[1] } grep { $_->[1] } @{ $self->{ blocks } };
    my $ev  = $has_new_style_ev ? " {" . join( ", ", @evs ) . "}" : "{" . join( ",", @evs ) . "}";
    $self->evidenceTags( $ev ) if @evs;

    $self->{ topic }   = $topic;
    $self->{ form }    = $form;
    $self->{ comment } = join( ". ", map { $_->[0] } @{ $self->{ blocks } } )."."; # build comment (all sentences) string without evs!

  }
  else {
      $self->initialize;
  }
  
  $self->{ _dirty } = 0;
  
  return $self;
}


sub blocks2String { # class / static method: blocks : [ [ String, String ], ... ] -> String
    # serialize back to string sentence-ev blocks
    my $blocks    = shift;
    my $ev4compat = shift;
    my $termin    = shift; ;#shift // "."; # // does not work with old perl
       $termin    = "." unless defined( $termin ); # defaut "." for real free text. multi/single sentence-ev in stuctured txt might need distinct sentence terminator (generaly "")

    my $has_new_style_ev = grep { $_->[1] =~ /ECO:/ } @$blocks;
    my $core = "";
    if ( $ev4compat && $ev4compat ne "{}" && @$blocks == 1 ) { 
        # if ev4compat (ev comming from evidenceTag method/field on BaseClass) not empty and there is only one block (= old non block style or new style with one block):
        # use this ev4compat instead evs stored in blocks! To be compatible with ev manip via "old" BaseClass::...EvidenceTag methods. FIXME: remove that mess!?
        $core = $blocks->[0]->[0] . ( $ev4compat =~ /^ / ? "." : "" ) . $ev4compat;
    }
    elsif ( $has_new_style_ev ) {
        $core = join ". ", map { $_->[0] . ( $_->[1] ? "${termin} {$_->[1]}" : "" ) } @$blocks;
    }
    else {
        $core = join ". ", map { $_->[0] . ( $_->[1] ? "${termin}{$_->[1]}" : "" ) } @$blocks;
    } 
          
    return $core;
}


sub toString {
  
    my $self  = shift;
    my $topic = $self->{ topic };
    my $form  = $self->{ form };
    my $core  = "";

    if ( $topic ne "MASS SPECTROMETRY" ) {
        $core = blocks2String( $self->{ blocks }, $self -> evidenceTags );
    }
    else {
        my $evs = $self->{ blocks }->[0]->[1];
        $evs = "{".$evs."}" if $evs;
        $core = $self->{ blocks }->[0]->[0].$evs;
    }

    my $text = "CC   -!- ";
    $text = $text . $topic . ": " if $topic;
    $text = $text . '['. $form . ']: ' if $form;
    $text = $text . $core if $core;

    # specific fix for dealing with the format of 1 special CC section

    # note in general text wraping in comments is not guaranteed to be read-safe by SWISSKNIFE

    # this specific fix keeps wrapping correct for 1 structured CC line, a better alternative would be to implement this section as a new class

    if ( defined( $topic ) and $topic eq "WEB RESOURCE" ) {

        my $newText = "";

        sub wrap {
            my $str      = shift or return;
            my $has_head = shift;
            $str         = ( $has_head ? '' : 'CC       ' ).$str;
            return SWISS::TextFunc->wrapOn('', "CC       ", $SWISS::TextFunc::lineLength, $str );
        }

        my @towrap;
        my $has_head = 1;

        foreach my $elem (split /;\s*/, $text) {

            unless ($elem =~ /https?:\/\/|[st]?ftp:\/\//) { # normal element, can be wrapped
                push @towrap, $elem;
            }
            else { # URL non wrapable str: put it on a new line (without wrap)

                # wrap what's before elem:
                $newText .= wrap(join('; ',@towrap).';',$has_head) if @towrap;
                @towrap = ();
                $has_head = 0;

                # add element on new line
                $elem = 'CC       '.$elem unless $elem =~ /^CC   /;
                $newText .= $elem.";\n";
            }
        }

        if (@towrap) { # add remaining txt if any
            $newText .= wrap(join('; ',@towrap).';',$has_head);
        }

        return $newText;
    }
    else { # for all other CC blocks: just warp the whole block (here large 'words' might be wrapped on 2 lines)
        # fix ./; endings
        if ( $topic eq "MASS SPECTROMETRY" ) {
            $text .= ";" unless $text =~ /;$/
        }
        else { $text .= "."; }
        # wrap
        $text = SWISS::TextFunc->wrapOn('',"CC       ", $SWISS::TextFunc::lineLength, $text);

        return $text;
    }
}


sub topic {
    my ( $self, $value ) = @_;
    if (defined $value) {
        $self->{'topic'} = $value;
    }
    return $self->{'topic'};
}


sub form {
    my $self = shift;
    return $self->{ form };
}


sub comment {
    my ($self,$value) = @_;
    if (defined $value) {
        $self->{'comment'} = $value;
    }
    return $self->{'comment'};
}

1;

__END__

=head1 Name

SWISS::CC.pm

=head1 Description

B<SWISS::CC> represents a comment on a single topic within a SWISS-PROT or TrEMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .  Each comment is stored in a
separate object, either of the type SWISS::CC or of another type,
depending on its topic (see SWISS::CCs for more information).
   
Collectively, comments of all types are stored within a SWISS::CCs container
object.

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item topic

The topic of this comment.

=item form

The protein form concerned by this comment (undef/empty = canonical/displayed form OR unknown)

=item comment

The text of this comment.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
