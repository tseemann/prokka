package SWISS::Stars::EV;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;


BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');
  
  %fields = (
	    );

}

=head2 new

=cut
sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::ListBase;
  
  $self->rebless($class);
  return $self;
}
 
=head2 fromText

=cut
sub fromText {
  my $self = new(shift);
  my $textRef = shift;
  my ($block, $line);

  # The tag for the EV section is 'EV'
  if ($$textRef =~ /((\*\*EV .*\n)+)/m) {
    $block = $1;

    # delete trailing dots and spaces
    $block =~ s/[\.\s]+\n/\n/gm;

    # unwrap multi-line evidence tags
    $block =~ s/\n\*\*EV\s{5}/ /gm;

    # now every comment is in a single line
    foreach $line (split /\n/, $block){
      $line = SWISS::TextFunc->cleanLine($line);

      push (@{$self->list()}, [split(/\;\s*/, $line)]);
    };
  };

  # we have only read, so the object is still clean
  $self->{_dirty} = 0;

  return $self;
}

=head2 toText

=cut
sub toText {
  my $self = shift;
  my ($textRef) = @_;
  my $newText = '';
  my $tag = 'EV';

  $self->sort(); # always sort!

  # assemble new lines  
  map ({$newText .= SWISS::TextFunc->wrapOn("\*\*$tag ", 
					    "\*\*$tag     ",
					    $SWISS::TextFunc::lineLengthStar,
					    $_ . '.',
					    '; ', ',\s*')} 
       (map {join("; ", @$_)} $self->elements)
      );

  # insert new text
  SWISS::Stars::insertLineGroup($self, $textRef, $newText, $tag);

  # now the object is clean
  $self->{_dirty} = 0;

  return 1;
}

=head2 sort

=cut
sub sort {
    my $self = shift;

    my $is_new_style = grep { $_->[0] =~ /^ECO/ } $self->elements;
    
    if ( $is_new_style ) {
        @{$self->list} = sort { # p.s. ->[0] eco code, e.g. ECO:0000269, ->[1]  source (with id) e.g. PubMed:15466860, ->[2] curator id, ->[3] date
            $a->[0] cmp $b->[0] || lc( $a->[1] ) cmp lc( $b->[1] ) || $a->[2] cmp $b->[2]; #Sort by <code>, For the same <code>, sort by <source>, For the same <source>, sort by <id>
        } $self->elements;
    } 
    else {
    	my ($x, $y, $u, $v);
        @{$self->list} = sort { ($u, $x) = @$a[0] =~ /(E[ACIP])(\d+)/;
            ($v, $y) = @$b[0] =~ /(E[ACIP])(\d+)/;
            $u cmp $v
            or
            $x <=> $y;} $self->elements;
    } 

    $self->{_dirty} = 1;

    return 1;
};

=head2 addEvidence( $evcode, $src, $author [, $date] )

 Title:    addEvidence

 Usage:    $evidenceTag = $entry->Stars->EV->addEvidence($evcode, 
                                                         $src, 
                                                         $author 
                                                         [, $date])

 Function: adds the evidence to the EV block if it does not yet exist 
           or returns the correct evidence tag if the evidence already exists, 
           possibly with a different date.

 Args:    $evcode: the evidence code. e.g. ECO:0000269
          $src:    the source. e.g. PubMed:11433298 
          $author: the author (initials). e.g. XXX p.s. For programs this could be '-'.
          $date: optional. If present, it must be in standard SWISS-PROT 
                 date format. If not present the current date will be used.

 Returns: The correct evidence tag.

=cut

sub addEvidence {
  my $self                             = shift;
  my ( $evcode, $src, $author, $date ) = @_; # p.s. now only for new style evidences (Aug 2014)
  
  # set $date
  unless ( $date ) {
    $date = SWISS::TextFunc::currentSpDate;      
  }
  
  return $self->_addEvidence( $evcode, $src, $author, $date ); 
}

=head2 updateEvidence( $evcode, $src, $author [, $date] )

 Title:    updateEvidence

 Usage:    $evidenceTag = $entry->Stars->EV->updateEvidence($evcode, 
                                                            $src, 
                                                            $author 
                                                            [, $date])

 Function: updates the evidence to the EV block to $date or inserts it 
           if it does not yet exist.

 Args:    $evcode: the evidence code. e.g. ECO:0000269
          $src:    the source. e.g. PubMed:11433298 
          $author: the author (initials). e.g. XXX p.s. For programs this could be '-'.
          $date: optional. If present, it must be in standard SWISS-PROT 
                 date format. If not present the current date will be used.

 Returns: The correct evidence tag.


=cut

sub updateEvidence{
    my $self                             = shift;
    my ( $evcode, $src, $author, $date ) = @_;
  
    # set $date
    unless ( $date ) {
        $date = SWISS::TextFunc::currentSpDate;      
    }
  
    return $self->_addEvidence( $evcode, $src, $author, $date, 1 ); 
}

# if $update is set, the evidence date will be updated if the entry already
# exists.
sub _addEvidence{
    my $self                                      = shift;
    my ( $evcode, $src, $author, $date, $update ) = @_;
   
    # check evcode
    unless ( $evcode =~ /^ECO:/ ) {
        croak( "Wrong evidence code type \'$evcode\'\n" );
    }

    # set $date
    $date = SWISS::TextFunc::currentSpDate unless $date;      
  
    # is ev to be added is already present (code and src)
    my @found = grep { $_->[ 0 ] eq $evcode && $_->[ 1 ] eq $src } $self->elements;
  
    $self->{ _dirty } = 1;
    
    my $ev    = [];
    my $evtag = '';
    if ( !@found ) { # ev is new, insert it
        $ev = [ $evcode, $src, $author, $date ];
        $self->add( $ev );   
    } 
    else {
        $ev = $found[ 0 ];
        if ( $update ) {
            $ev->[ 2 ] = $author;
            $ev->[ 3 ] = $date;
        }
    }

    return $ev->[0].'|'.$ev->[1];
 
}

sub max {
  my ($a, $b) = @_;
  if ($a > $b) {
    return $a;
  } else {
    return $b;
  }
}

1;				# says use was ok

=head1 Name

SWISS::Stars::EV.pm

=head1 Description

B<SWISS/Stars/EV.pm> represents the evidence section within an SWISS-PROT + TrEMBL entry. See http://www3.ebi.ac.uk/~sp/intern/projects/evidenceTags/index.html

For a usage example, see evTest.pl in the Swissknife package.

=head1 Inherits from
SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>
Each element of the list describes one evidence, itself represented as an array.

=back
