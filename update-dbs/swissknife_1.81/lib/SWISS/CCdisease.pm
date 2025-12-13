package SWISS::CCdisease;

use vars qw($AUTOLOAD @ISA @_properties %fields);

use Carp;
use strict;
use SWISS::TextFunc;
use SWISS::BaseClass;

BEGIN {
  @ISA = ('SWISS::BaseClass');

  %fields = (
	   disease      => undef,
	   mim          => undef,
	   descritption => undef,
       note         => undef
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
    my $class = shift;
    my $textRef = shift;
    my $self = new SWISS::CCdisease;

    my $text = $$textRef;
    $self->initialize();

    $self->{ disease }       = undef; # [ txt, ev ];
    $self->{ mim }           = undef; #   txt;
    $self->{ description }   = undef; #   txt;
    $self->{ note }          = undef; # [[ sentence, ev ]];
    $self->{ is_old_format } = 1; # p.s. if old non structured format, all is in note field (but do not show Note=)
  
    $self->{_dirty} = 0;
    if ( $text =~ /^ *-!- DISEASE: +(?:\[(.+)\]:)?\s*(\S.+?\]): (.+?)$/ ) { # new format with named disease
		$self->{ is_old_format } = 0;
		$self->{ form }          = $1;
		my $disease = $2;
		my $rest    = $3;
		my ( $descev, $note ) = split( /\.? Note=/, $rest );
		my $p_desc_ev = _parse_txt_ev( $descev );
		my $mim = $disease =~ /\[MIM:(\d+)\]/ ? $1 : undef;	
		$self->{ disease }     = [ $disease, $p_desc_ev->[1] ];
		$self->{ mim }         = $mim;
		$self->{ description } = $p_desc_ev->[0];
		$self->{ note }        = SWISS::CC::parse2Blocks( $note );
    }
    elsif ( $text =~ /^ *-!- DISEASE: Note=(.+?)$/ ) { # newish format without a named disease (but has Note= that now could be multi sentence-ev !)
		$self->{ is_old_format } = 0;
		$self->{ note }          = SWISS::CC::parse2Blocks( $1 );
    }
    elsif ( $text =~ /^-!- DISEASE: (.+)\.?$/ ) { # old format not structured
        $self->{ is_old_format } = 1;
        $self->{ note }          = SWISS::CC::parse2Blocks( $1 ); # old format: only one block sentence(s)-ev but use parse2Blocks anyway to have uniform data stucture
    }
  
    return $self;
}


sub _parse_txt_ev {
    my $txt = shift;
    
    my ( $evidence ) = $txt =~ /($SWISS::TextFunc::evidencePattern)/m;
    if ( $evidence ) {
        my $quotedEvidence = quotemeta $evidence;
        $txt =~ s/$quotedEvidence//m;
    }
    $txt =~ s/\.$//;

    return [ $txt, $evidence ];
}


sub toString {
	my $self = shift;

	my $form = $self->{ form };
 	my $text = "CC   -!- DISEASE: ";
	$text .= '['. $form . ']: ' if $form;
	$text .= $self->comment;
 	
 	$text = SWISS::TextFunc->wrapOn( '', "CC       ", $SWISS::TextFunc::lineLength, $text);
 	
 	return $text;
}


sub comment {
	my $self = shift;
	
	my $text = "";
	if ( defined $self->{ disease } ) { # "controled" disease (only new format)
  		my $d_ev = $self->{ disease}->[ 1 ];
  		$text .= $self->{ disease }->[ 0 ].": ".$self->{ description };
  		if ( $d_ev && $d_ev ne '{}' ) {
  			my $extra = $self->{is_old_format} ? "" : ".";
  			$text .= $extra.$d_ev
  		}
  		$text .= ".";
  		$text .= " " if defined $self->{note};
	}
	if ( defined $self->{note} ) {
  		my $note = SWISS::CC::blocks2String( $self->{ note } );
        $text   .= ( $self->{is_old_format} ? "" : "Note=" ).$note."."; # yes even with new structured format ends with . (instead of ;)
	}

	return $text;
}


sub topic {
	return "DISEASE";
}


sub form {
	my $self = shift;
	return $self->{ form };
}


sub disease {
	my ( $self, $value, $ev ) = @_;
    
	if ( defined $value ) {    
		my $new_ev = $ev ? $ev : $self->{ disease }->[0];
    	$self->{ disease } = [ $value, $new_ev ];
  	}
    
  	return $self->{ disease };
}


sub mim {
    my ( $self, $value ) = @_;
    
    if ( defined $value ) {    
        $self->{ mim } = $value;
    }
    
    return $self->{ mim };
}


sub description {
	my ( $self, $value ) = @_;
    
	if ( defined $value ) {    
    	$self->{ description } = $value;
  	}
    
  	return $self->{ description };
}


sub note {
	my ( $self, $ref ) = @_;
    
    if ( defined $ref ) {
    	$self->{ note } = $ref;
	}
    
  	return $self->{ note };
}


1;

__END__

=head1 Name

SWISS::CCdisease.pm

=head1 Description

B<SWISS::CCdisease> represents a comment on the topic 'DISEASE'
within a Swiss-Prot or TrEMBL entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .  Comments on other topics are stored
in other types of objects, such as SWISS::CC (see SWISS::CCs for more information).

Collectively, comments of all types are stored within a SWISS::CCs container
object.

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item topic

The topic of this comment ('DISEASE').

=item form

The protein form concerned by this comment (undef/empty = canonical/displayed form OR unknown

=back
=head1 Methods

=over

=item disease

The name and evidence of the disease (only for new structured CC diseases)
reference to an array [ $disease, $disease_ev ]

=item disease( $new_disease, $new_disease_ev )

Set disease to $new_disease, $new_disease_ev

=item mim

The disease mim id (only for new structured CC diseases)

=item mim( $new_mim )

Set mim to $new_mim

=item description

The disease description (only for new structured CC diseases)

=item note

The note and evidence of the disease (Note= in new CC disease format or full description in old format)
reference to an array of [ $block_txt, $block_ev ] arrays

=item note( [[ $block_txt, $block_ev ]...] )

Set note to array of [  $block_txt, $block_ev ] arrays

=item comment

The "text" version of this comment.

=back
=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
