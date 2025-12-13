package SWISS::CCinteraction;

use vars qw($AUTOLOAD @ISA);

use Carp;
use strict;
use SWISS::TextFunc;
use SWISS::ListBase;

BEGIN {
  @ISA = ('SWISS::ListBase');
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
    my $self = new SWISS::CCinteraction;
    my $text = $$textRef;
    $self->initialize();
    $text =~ s/ +/ /g;

    #my $ac_pattern    = "(?:[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z](?:[0-9][A-Z][A-Z0-9]{2}){1,2}[0-9])";
    #my $isoid_pattern = "$ac_pattern-[0-9]+";
    #my $proid_pattern = "PRO_[0-9]{10}";

    $text =~ s/\s*-!-.*?:\s*//;
    while (length $text) {
        if ( $text =~ s/^\s*([\w\-]+); ([\w\-]+|PRO_[0-9]{10} \[\w+\])(?:: (.+?))?;( Xeno;)? NbExp=(\d+); IntAct=(EBI-\d+, EBI-\d+);//so ) {
            # 2020_02 format
            my ( $interactant_from, $interactant_to, $gene_name, $xeno, $nbexp, $intact ) = ( $1, $2, $3, $4, $5, $6 ); # Interactants should be valid Swiss-Prot AC or IsoId or ProId; this is not checked here.
            my %arg;
            $arg{ 'self' }        = $interactant_from; # "interactant 1"
            $arg{ 'interactant' } = $arg{ 'accession'  } = $interactant_to; # "interactant 2" # 'accession' used to be compatible with older version of CCinteraction API
            $arg{ 'gene_name' }   = $arg{ 'identifier' } = $gene_name;                        # 'identifier' used to be compatible with older version of CCinteraction API
            ( $arg{ 'xeno' }      = $xeno ) =~ s/;$//;
            $arg{ 'nbexp' }       = $nbexp;
            $arg{ 'intact' }      = [split /, */, $intact];
            $self->push(\%arg);
        }
        elsif ( $text =~ s/^\s*(([\w\-]+):(.+?)( \(xeno\))?|Self)\s*(;\s+|;\Z)//so ) { # old format
            my ( $t, $ac, $identifier, $xeno ) = ( $1, $2, $3, $4 );
            my %arg;
            $arg{ 'interactant' } = $arg{ 'accession' } = $t eq 'Self' ? $t : $ac;
            $arg{ 'gene_name' }   = $arg{ 'identifier' } = $identifier if defined $identifier;
            $arg{ 'xeno' } = $xeno if defined $xeno;
            while ($text =~ s/^(NbExp|IntAct)=(.*?)\s*(;\s+|;\Z)//) { # extra fields
                my ($field, $ltext) = ($1, $2);
                if ($field eq 'IntAct') {
                  $arg{lc($field)} = [split /, */, $ltext];
                }
                else {
                  $arg{lc($field)} = $ltext;
                }
            }
            $self->push(\%arg);
        }
        else {
            carp "CC INTERACTION parse error, ignoring $text";
            last;
        }
    }
    $self->sort;
    $self->{_dirty} = 0;
    return $self;
}

sub sort {
  my ( $self ) = @_;
  if ( $self ) {
    $self->set (
      ( sort {
      ( my $a_mol_a_base = $a->{self}||'' ) =~ s/-.+$//;
      ( my $b_mol_a_base = $b->{self}||'' ) =~ s/-.+$//;
      ( my $a_mol_a_ison = $a->{self}||'-' ) =~ s/^[^-]*-/0/;
      ( my $b_mol_a_ison = $b->{self}||'-' ) =~ s/^[^-]*-/0/;

      ( my $a_mol_b_ac = $a->{interactant}||'-' ) =~ s/PRO_\d+ \[|\]$//g;
      ( my $b_mol_b_ac = $b->{interactant}||'-' ) =~ s/PRO_\d+ \[|\]$//g;
      ( my $a_mol_b_base = $a_mol_b_ac ) =~ s/-.*$//;
      ( my $b_mol_b_base = $b_mol_b_ac ) =~ s/-.*$//;
      ( my $a_mol_b_ison = $a_mol_b_ac ) =~ s/^[^-]*-/0/;
      ( my $b_mol_b_ison = $b_mol_b_ac ) =~ s/^[^-]*-/0/;
     
               ( $a->{self}||'' )=~/^PRO_/        <=>        ( $b->{self}||'' )=~/^PRO_/ # mol A not PRO first,
          ||     $a_mol_a_base                    cmp          $b_mol_a_base # mol A core AC
          ||     $a_mol_a_ison                    <=>          $b_mol_a_ison # mol A isoform number (canonical=0 = is first)
          || defined( $a->{xeno} )                <=> defined( $b->{xeno} ) # not xeno
          || defined( $b->{gene_name} )           <=> defined( $a->{gene_name} ) # has gene name
          || lc( $a->{gene_name}||'' )            cmp     lc ( $b->{gene_name}||'' ) # gene name lc (= case insensitive)
          ||     $a_mol_b_base                    cmp          $b_mol_b_base # mol B core AC (for PRO.. use [AC])
          ||   ( $a->{interactant}||'' )=~/^PRO_/ <=>        ( $b->{interactant}||'' )=~/^PRO_/ # mol B not PRO
          ||     $a_mol_b_ison                    <=>          $b_mol_b_ison # mol B isoform number (canonical=0 = is first)
          ||   ( $a->{interactant}||'' )          cmp        ( $b->{interactant}||'' ) # mol B identifier
      } ( $self->elements ) )
    );
  }
}

sub toString {
  my $self = shift;
  my $text = "-!- INTERACTION:\n" . $self->comment;
  $text =~ s/^/CC       /mg;
  $text =~ s/    //;
  return $text;
}

sub topic {
  return "INTERACTION";
}

sub comment {
  my ($self) = @_;
  my $text = "";
  if ($self) {
    for my $el ($self->elements) {
      my $is_new_format = $el->{self};
      $text .= $el->{self}."; " if defined $el->{self};
      $text .= $el->{interactant};
      $text .= ":" . ( $is_new_format ? ' ' : '' ) . $el->{gene_name} if defined $el->{gene_name};
      $text .= ( $is_new_format ? ';' : '' ) . $el->{xeno} if defined $el->{xeno};
      $text .= ";";
      $text .= " NbExp=" . $el->{nbexp} . ";" if defined $el->{nbexp};
      $text .= " IntAct=" . join (", ", @{$el->{intact}}) . ";" if defined $el->{intact};
      $text .= "\n";
    } #!? old format could have other extra param than nbexp & intact !? won't be serialized here!
  }
  $text;
  
}

1;

__END__

=head1 Name

SWISS::CCinteraction

=head1 Description

B<SWISS::CCinteraction> represents a comment on the topic 'INTERACTION'
within a Swiss-Prot or TrEMBL entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .  Comments on other topics are stored
in other types of objects, such as SWISS::CC (see SWISS::CCs for more information).

Collectively, comments of all types are stored within a SWISS::CCs container
object.

Each element of the list is a hash with the following keys:

  'interactant' (previously named 'accession') accession or IsoId or ProId [accession] of "interactant 2"
  'identifier'  (previously named 'identifier') gene name (of "interactant 2")
  'self'        accession or IsoId or ProId of "interactant 1" (that should come from the src entry itself)
  'xeno'
  'nbexp'
  'intact'      (array reference)

=head1 Inherits from

SWISS::ListBase.pm

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
