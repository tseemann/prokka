package SWISS::PE;

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
  my $self    = new(shift);
  my $textRef = shift;
  my $text    = "";
  
  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'PE'})/m){   
		$text = $1;
		$self->{indentation} += $text =~ s/^ //;
		$text = SWISS::TextFunc->cleanLine($text);
	
		if ($text =~ s/($SWISS::TextFunc::evidencePattern)//) {
			$self->evidenceTags($1);
		}
		
		$self->text($text);
	}
	
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  
  if ($self->text) {
		return $self->text . $self->getEvidenceTagsString;
	}
}

1;

__END__

=head1 Name

SWISS::PE

=head1 Description

Indicates what kind of evidence there is for the existence of a protein.

=head1 Inherits from

SWISS::BaseClass

=head1 Attributes

=over

=item C<text>

The type of evidence.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
