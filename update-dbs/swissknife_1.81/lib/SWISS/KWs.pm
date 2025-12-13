package SWISS::KWs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::KW;


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
    my $self    = new(shift);
    my $textRef = shift;

    if ( $$textRef =~ /($SWISS::TextFunc::linePattern{'KW'})/m ) {   
        ( my $raw_data_block = $1 ) =~ s/^( *)KW   //mg;
        $self->{ indentation } = 1 if $1;
        foreach my $kw ( split /;\s?|\.\s?$/m, $raw_data_block ) {
            $kw =~ s/ *\r?\n/ /g;
            push @{ $self->list() }, SWISS::KW->fromText( $kw );
        }
    }

    $self->{ _dirty } = 0;
    return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my @lines;
  my $newText = '';

  if ($self->size > 0) {
    $newText = join('; ', map {$_->toText()} @{$self->list}) . ".";
    my $prefix = "KW   ";
    my $col = $SWISS::TextFunc::lineLength;
    $col++, $prefix=" $prefix" if $self->{indentation};
    $newText = SWISS::TextFunc->wrapOn($prefix, $prefix, $col,
				       $newText , ';\s+');
  };

  $self->{_dirty} = 0;

  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
			     $SWISS::TextFunc::linePattern{'KW'});
}

sub sort {
  my $self = shift;

  return $self->set(sort {lc($a->text) cmp lc($b->text)} @{$self->list});
}

1;

__END__

=head1 Name

SWISS::KWs

=head1 Description

B<SWISS::KWs> represents the KW lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

Each list element is a B<SWISS::KW> object. 

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item sort

sort() sorts the keywords alphabetically.

=item toText

=back
