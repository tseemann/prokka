package SWISS::Refs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields $opt_debug);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::Ref;


BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');
  
  %fields = (
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
  my $self = new SWISS::Refs;

  my $ref;

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'R.'})/m){
    foreach $ref (split /(?=^ ?RN)/m, $1) {
      $self->push(SWISS::Ref->fromText(\$ref));
    }
  }
  else {
    $self->initialize;
  };
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my $newText = '';
  my $ref;
  
  foreach $ref (@{$self->list}) {
    $newText .= $ref->toText;
    # Now text and object representation are being synchronised, reset
    # the _dirty flag of $ref.
    $ref->{_dirty} = 0;
  };
  
  if (defined $main::opt_debug && $main::opt_debug>1) {
    print STDERR "$newText";
  };

  $self->{_dirty} = 0;

  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'R.'});
  
}

# Overwrite the inherited sort method.
sub sort {
  my ($self) = @_;
  return $self->set(sort {$a->RN <=> $b->RN} @{$self->list});
  return 1;
}

# Overwrite the inherited update method.
sub update {
  return 1;
}

1;

__END__

=head1 Name

SWISS::Refs.pm

=head1 Description

B<SWISS::Refs> represents the Reference lines within an SWISS-PROT + TREMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

  A list of SWISS::Ref objects. Each object represents one reference.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
