package SWISS::CCs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields %TOPICS);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::CC;
use SWISS::CCcopyright;
use SWISS::CCalt_prod;
use SWISS::CCrna_editing;
use SWISS::CCbpc_properties;
use SWISS::CCinteraction;
use SWISS::CCseq_caution;
use SWISS::CCdisease;
use SWISS::CCsubcell_location;
use SWISS::CCcofactor;
use SWISS::CCcatalytic_activity;


BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');
  
  %fields = (
	    );  
}

# CAUTION: CC order (for sorting) is hard-coded here down in: __DATA__

#initialization code: stuff DATA into hash
{
  # Leading and trailing spaces are MANDATORY!
  local $/="\n";
  my $index=0;
  my $line;
  while (defined ($line=<DATA>)) {
    $line =~ s/\s+\z//;
    $TOPICS{$line} = $index++;
  }
  $TOPICS{'Copyright'} = $index++;
  close DATA;
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
  my $line;

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'CC'})/m) {   
    
    my $block = $1;
    my ($main, $copyright) = split /CC   +-{40,78}\nCC/, $block;
    
    # can't get regexp to work with two optional components to a block
    #  ($block =~ /(.*)?(CC   -{40,78}\n(.*\n)*CC   -{40,78})*\n/s);
    
    # process each non-copyright comment type
    foreach $line (split /\n(?= ?CC   +-!-)/m, $main) {
      
      my $indentation = $line =~ s/^ //mg;
      $line = SWISS::TextFunc->cleanLine($line);
      my $cc = _chooseType($line); 
      $cc->{indentation} = $indentation if $indentation;
      push (@{$self->list()}, $cc); 
    }
    
    # process copyright
    if (defined $copyright) {
      $copyright =  "CC   -----------------------------------------------------------------------\nCC".$copyright;
      $copyright =~ s/-{40,78}\r?\n$/-----------------------------------------------------------------------/;
      push (@{$self->list()}, _chooseType($copyright)); 
    }
  } 
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my @lines;
  my $newText = '';

  if (! $self->isEmpty()){
  
    $newText = join('', map {
      my $str = $_->toString();
      $str =~ s/^/ /mg if $_->{indentation};
      $str;
      } @{$self->list});
  };

  $self->{_dirty} = 0;
  return SWISS::TextFunc->
    insertLineGroup($textRef, $newText, $SWISS::TextFunc::linePattern{'CC'});
}

sub toString {
  
  my $self = shift;
  my $string = "";
  $self -> toText(\$string);
  return $string;
}

sub _chooseType {

  my $text = shift;
  my $CCs;
  
  # preparse text into a single line 
  
  $text =~ s/-\nCC {7}(AND|OR|AND\/OR) /- $1 /mgi;
  # unwrap things like '-Val- bond' and 'Leu-|- bonds' (but not 'disulfide-bond') with space
  $text =~ s/(\b[A-Z]{3}-|-\|-)\nCC {7}(BOND)/$1 $2/mgi;
  $text =~ s/(?<!\/)-\nCC {7,}/-/mg;# wrap dash cr without space (except in "+/-")
  $text =~ s/\nCC {7}/ /mg;    # wrap other cr with space
  $text =~ s/^CC   -!-\s*//mg; # strip line tags and spaces
  $text =~ s/[\.\s]+$//mg;     # and trailing dots and spaces
  
  # get one of three types of objects as is appropriate

  if ($text !~ /-\!/) {
  
    ## copyright notice
    
    $text =~ s/[\.\s]+$//mg; 
    $CCs = SWISS::CCcopyright->fromText(\$text);
  
  }  elsif (($text =~ /-!- ALTERNATIVE PRODUCTS/) && ($text =~ /Event=/)) {
  
    # new format alternative products
    
    $CCs = SWISS::CCalt_prod->fromText(\$text);
  
  }  elsif (($text =~ /-!- BIOPHYSICOCHEMICAL PROPERTIES/)) {
    $CCs = SWISS::CCbpc_properties->fromText(\$text);
  }  elsif (($text =~ /-!- INTERACTION/)) {
    $CCs = SWISS::CCinteraction->fromText(\$text);
  }  elsif (($text =~ /-!- RNA EDITING/)) {
    $CCs = SWISS::CCrna_editing->fromText(\$text);
  }  elsif (($text =~ /-!- SEQUENCE CAUTION/)) {
    $CCs = SWISS::CCseq_caution->fromText(\$text);
  }  elsif (($text =~ /-!- DISEASE/)) {
    $CCs = SWISS::CCdisease->fromText(\$text);
  } elsif (($text =~ /-!- SUBCELLULAR LOCATION/)) {
    $CCs = SWISS::CCsubcell_location->fromText(\$text);
  } elsif (($text =~ /-!- COFACTOR/)) {
    $CCs = SWISS::CCcofactor->fromText(\$text);
  } elsif (($text =~ /-!- CATALYTIC ACTIVITY/)) {
    $CCs = SWISS::CCcatalytic_activity->fromText(\$text);
  } else {
    # standard
    $CCs = SWISS::CC->fromText(\$text);
  }
  
  return $CCs;
}

sub sort {
  my $self = shift;
  my $n = $self->size();  return 1 if $n < 2;
  my $rary = $self->list();
  my $disorder;
  # nearly all entries will be in order, so test for it
  for (my $i=1; $i<$n; $i++) {
    if (_sort_cmp($rary->[$i-1], $rary->[$i]) > 0){
      $disorder=1;
      last;
    } 
  }
  return 1 unless $disorder;
 
  # simple sort to preserve order of same topics
  for (my $i=1; $i < $n; $i++){ 
    for (my $j=1; $j < $n; $j++){
      if (_sort_cmp($rary->[$j-1], $rary->[$j]) > 0){
        ($rary->[$j-1],$rary->[$j]) = ($rary->[$j],$rary->[$j-1]); 
      }
    }
  }
  return 1;
}

sub _sort_cmp {
	my ($cc1, $cc2) = @_;
	my $topic_1 = $cc1->topic;
	my $topic_2 = $cc2->topic;

	if ($topic_1 eq 'SIMILARITY' && $topic_2 eq 'SIMILARITY') {
		my $c_1 = $cc1->comment;
		my $c_2 = $cc2->comment;
		my @ord;
		for my $c ($c_1, $c_2) {
			if ($c =~ /\bbelongs to\b/i) {
				push @ord, 1;
			}
			elsif ($c =~ /^Contains\b/i) {
				push @ord, 2;
			}
			else {
				push @ord, 3;
			}
		}
		return $ord[0] <=> $ord[1] if $ord[0] != $ord[1];
		if ($c_1 =~ /^CONTAINS (?:AT LEAST )?(?:\d+|\?) (.*)/i) {
			my $t_1 = $1;
			if ($c_2 =~ /^CONTAINS (?:AT LEAST )?(?:\d+|\?) (.*)/i) {
				return lc($t_1) cmp lc($1) || $t_1 cmp $1;
			}
		}
		return 0;
	}
	return $TOPICS{$topic_1} <=> $TOPICS{$topic_2};
}


sub update {
  my $self = shift;
  my $force = shift;
  # CCs should be sorted, but unique() does not make sense
  $self->sort();
  return 1;
}


sub get {

  # local override of global get method
  # get array of CC objects selected by topic

  my ($self, @patterns) = @_;
  my @result;

  # do nothing if the list is empty
  unless ($self->size > 0 ) {
    return ();
  };

  if ((ref $patterns[0] eq 'ARRAY')) {
    @patterns = @{$patterns[0]};
  };

  @result = @{$self->list};
  # empty patterns are regarded as matches.
  if (defined($patterns[0]) and $patterns[0] ne ""){
    @result = grep { $_->topic() =~ /^$patterns[0]$/ } @result;
  }
  if (defined($patterns[1]) and $patterns[1] ne ""){
    @result = grep { $_->comment() =~ /^$patterns[1]$/ } @result;
  }
  return @result;
}

sub unique {
  my ($self) = @_;

  my ($i, $j);
  for ($i = 0; $i < $#{$self->{list}}; $i++) {
    my $item1 = ${$self->list}[$i];
    for ($j = $i+1; $j <= $#{$self->{list}}; $j++) {
      my $item2 = ${$self->list}[$j];
      if ($item1->topic eq $item2->topic and $item1->comment eq $item2->comment) {
        splice @{$self->list}, $j--, 1;
      }
    }
  }
  return 1;
}

sub getObject {

  # local override of global get method
  # get ListBase object of CC objects selected by topic

  my ($self, @patterns) = @_;
  my $new = new ref($self);
  $new->set($self -> get(@patterns));
  return $new;
}

sub del {

  # local override of global del method
  # delete CC objects if topic matches that specified
  
  my ($self, @patterns) = @_;
  my @result;
  my ($i, $pat, @elements);
  
  # do nothing if the list is empty
  
  unless ($self->size > 0 ) {
    return ();
  };

  @elements = @{$self->list};
  
  ELEMENT:for my $element (@elements) {  
    
    my $match = 0;
   
    if ($patterns[0]  && ($element->topic() =~ /^$patterns[0]$/)) {
	  
      if ((! $patterns[1]) || ($element->comment() =~ /^$patterns[1]$/)) {
          
        $match ++; 
      }
    }
    
    if ($match == 0) { 
      
      CORE::push (@result, $element);
	  }
	}
  
  return $self->set(@result);
}

sub copyright {

  # retrive copyright 
  
  my ($self) = @_;
  my @elements = @{$self->list};
  
  ELEMENT:for my $element (@elements) { 
  
    if ($element->topic() eq 'Copyright') {
    
      return $element -> toString();
    } 
  }
   
  return; 
}

sub ccTopic{
  my ($ccTopic) = @_;
  
  return sub {
    my $ref = shift;
    my $topic = $ref -> topic();

    return ($topic eq $ccTopic);
  }  
}


1;

=head1 Name

SWISS::CCs

=head1 Description

B<SWISS::CCs> represents the CC lines within a Swiss-Prot or TrEMBL
entry as specified in the user manual
 http://www.expasy.org/sprot/userman.html . The CCs object is a 
container object which holds a list comprised of object of
the type SWISS::CC or derived classes (see below).

B<Code example>

local $/="\n//\n";
 
while (<>) {
 
  my $entry = SWISS::Entry-> fromText($_);
  my @CCs = $entry -> CCs -> elements();
 
  for my $CC (@CCs) {
     
    if ($CC -> topic eq 'ALTERNATIVE PRODUCTS') {
    
      # now can call methods of CCalt_prod 
    
    } elsif ($CC -> topic eq 'Copyright') {
    
      # now can call methods of CCcopyright
    
    } else {
    
      # now can call methods of CC
    }
  }
}

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

Each list element is an object of one of the following classes,
depending of the type of comment:

 topic                           object
 --------------------            --------------------
 ALTERNATIVE PRODUCTS            SWISS::CCalt_prod
 RNA EDITING                     SWISS::CCrna_editing
 BIOPHYSICOCHEMICAL PROPERTIES   SWISS::CCbpc_properties
 INTERACTION                     SWISS::CCinteraction
 COFACTOR                        SWISS::CCcofactor
 DISEASE                         SWISS::CCdisease
 SEQUENCE CAUTION                SWISS::CCseq_caution
 SUBCELLULAR LOCATION            SWISS::CCsubcell_location
 Copyright                       SWISS::CCcopyright
 (all other topics)              SWISS::CC

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item sort

Sort the CC block according to the order given in Swiss-Prot annotation
note ANN017.

=item toText

=item update

=back

=head2 Reading/Writing methods

=over

=item ccTopic ($topic)

Returns true if entry contains a comment block with the specified topic.

=item copyright

Returns a string representation of the copyright text.

=item del (@patternList)

Deletes all comment elements whose topic matches the first element
of the pattern list.  The second element is the used to specify a
requirement for the comment to match as well.

=item get (@patternList)

An array is returned consisting of all comment elements
elements whose topic matches any elements of the pattern list.

=item getObject (@patternList)

Same as get, but returns the results wrapped in a new ListBase object.  

=item toString

Returns a string representation of the CCs object.

=back

=cut

__DATA__
FUNCTION
CATALYTIC ACTIVITY
COFACTOR
ACTIVITY REGULATION
BIOPHYSICOCHEMICAL PROPERTIES
PATHWAY
SUBUNIT
INTERACTION
SUBCELLULAR LOCATION
ALTERNATIVE PRODUCTS
TISSUE SPECIFICITY
DEVELOPMENTAL STAGE
INDUCTION
DOMAIN
PTM
RNA EDITING
MASS SPECTROMETRY
POLYMORPHISM
DISEASE
DISRUPTION PHENOTYPE
ALLERGEN
TOXIC DOSE
BIOTECHNOLOGY
PHARMACEUTICAL
MISCELLANEOUS
SIMILARITY
CAUTION
SEQUENCE CAUTION
WEB RESOURCE
