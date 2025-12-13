package SWISS::OS;

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

  # reset the dot of terms like sp., but not of "Bacteriophage SP"
  $text =~ s/(( sp)|( spp)|( s\.n))\Z/$1\./;

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

SWISS::KWs

=head1 Description

B<SWISS::OS> represents one organism name from the OS line. The container object holding all organism lines is SWISS::OSs.

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<text>

One organism name.

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

