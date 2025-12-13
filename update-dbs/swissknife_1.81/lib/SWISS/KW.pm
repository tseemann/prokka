package SWISS::KW;

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
  my $self = new(shift);

  my $text = shift;

  # Parse out the evidence tags
  if ($text =~ s/($SWISS::TextFunc::evidencePattern)//) {
    my $tmp = $1;
    $self->evidenceTags($tmp);
  }

  $self->text($text);

  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  
  return $self->text . $self->getEvidenceTagsString;
}

1;

__END__

=head1 Name

SWISS::KW

=head1 Description

Each KW object represents one keyword. The container object for all keywords of an entry is SWISS::KWs

=head1 Inherits from

SWISS::BaseClass

=head1 Attributes

=over

=item C<text>

The text of the keyword.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
