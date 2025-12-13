package SWISS::OX;

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

  return $self;
}

sub toText {
  my $self = shift;
  
  return $self->text . $self->getEvidenceTagsString;
}

1;

__END__

=head1 Name

SWISS::OX

=head1 Description

B<SWISS::OX> represents one tax id from the OX line. The container object holding all tax ids is SWISS::OXs.


=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<text>

One tax id.

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head1 Example

see documentation of OXs.pm
