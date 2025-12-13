package SWISS::OCs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields $uppercase);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;

$uppercase = 0;

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
  my $self = new(shift);

  my $textRef = shift;
  my @tmp;

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'OC'})/m){   
    my $line=join " ", map {
      $self->{indentation} += s/^ //;
      SWISS::TextFunc->cleanLine($_)
    } split /\n/m, $1;
    @tmp = SWISS::TextFunc->listFromText($line, ';\s*', '\.\s*');
    push (@{$self->list()}, @tmp); 

  }
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my (@lines, $newText);
  
  return unless @{$self->list};

  $newText = join('; ', @{$self->list}) . ".";
  my $prefix = "OC   ";
  my $col = $SWISS::TextFunc::lineLength;
  $col++, $prefix=" $prefix" if $self->{indentation};
  $newText = SWISS::TextFunc->wrapOn($prefix, $prefix, $col,
				     $newText , ';\s+');

  $newText =~ tr/a-z/A-Z/ if $uppercase;
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
			     $SWISS::TextFunc::linePattern{'OC'});
}

# OCs must never be sorted, overwrite the inherited sort method.
sub sort {
  return 1;
}

1;

__END__

=head1 Name

SWISS::OCs

=head1 Description

B<SWISS::OCs> represents the OC lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

Each list element is an item giving one part of the taxonomic classification of the source organism of the protein.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=item sort

=back
