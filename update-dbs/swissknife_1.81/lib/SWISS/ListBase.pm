package SWISS::ListBase;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);
use Exporter;
use Carp;
use strict;
use Data::Dumper;

use SWISS::BaseClass;

# * Initialisation

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass' );
  
  %fields = (
	     list => undef,	# the main array
	    );
}

# * Standard methods

sub new {
  my ($ref) = @_;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::BaseClass;
  
  $self->rebless($class);

  return $self;
}

sub initialize {
  my ($self) = @_;
  
  $self->{'list'} = [];
  return $self;
}

# * Reading methods

sub head {
  my ($self) = @_;
  
  return @{$self->{'list'}}[0];
}

sub tail {
  my ($self) = @_;
  
  my @tmp = @{$self->{'list'}};
  
  CORE::shift(@tmp);
  
  return @tmp;
}

sub get {
  my ($self, @patterns) = @_;

  my @result;

  # do nothing if the list is empty
  unless ($self->size > 0 ) {
    return ();
  };

  # If first list element is a scalar
  if (not ref @{$self->list}[0]){
    return (grep {/^$patterns[0]$/} @{$self->list});
  };

  # If first list element is an array
  if (ref @{$self->list}[0] eq 'ARRAY') {

    # The list of patterns might have one element, which is a list.
    # Unwrap it.
    if ((ref $patterns[0] eq 'ARRAY')) {
      @patterns = @{$patterns[0]};
    };

    @result = @{$self->list};
    for (my $i=0; $i <= $#patterns; $i++) {
      my $pat = $patterns[$i];
      if (defined($pat) and $pat ne ""){
	@result = grep { $$_[$i] =~ /^$pat$/ } @result;
      }
      else {
	# empty patterns are regarded as matches.
	next;
      }
    }
    return @result;
  }
  
  # An undefined data type
  carp "get is currently not implemented for elements of type " . ref @{$self->list}[0];
  return undef;
}

# Only maintained for backward compatibility
sub mget {
  my ($self, @elements) = @_;

  confess "mget is deprecated. Please use get instead\n";

  return $self->get(@elements);
}

sub size {
  my ($self) = @_;

  return scalar(@{$self->{'list'}});
}

sub isEmpty {
  my ($self) = @_;
  
  return ($self->size == 0); 
}


sub elements{
  my ($self) = @_;

  return @{$self->{'list'}};
}


# * Writing methods

sub item {
  my ($self, $pos, $newValue) = @_;

  if ($newValue) { #set value
    return $self->{'list'}->[$pos] = $newValue;
  }
  else { #read value
    return $self->{'list'}->[$pos];
  }
}

sub push {
  my ($self, @elements) = @_;

  $self->{_dirty} = 1;
  
  return CORE::push(@{$self->{'list'}}, @elements);
}

sub pop {
  my ($self) = @_;
  
  $self->{_dirty} = 1;
  
  return pop(@{$self->{'list'}});
}

sub shift {
  my ($self) = @_;
  
  $self->{_dirty} = 1;
  
  return CORE::shift(@{$self->{'list'}});
}

sub splice {
  my ($self, $offset, $length, @elements) = @_;
  
  $self->{_dirty} = 1;

  if (defined $length) {
    return splice(@{$self->{'list'}}, $offset, $length, @elements);
  }
  else {
    return splice(@{$self->{'list'}}, $offset);
  }
}

sub unshift {
  my ($self, @elements) = @_;

  $self->{_dirty} = 1;
  
  return unshift(@{$self->{'list'}}, @elements);
}

sub set {
  my ($self, @elements) = @_;
  
  $self->{_dirty} = 1;
  
  @{$self->{'list'}} = @elements;
  return $self;
}

sub add {
  my ($self, @elements) = @_;

  $self->{_dirty} = 1;
  
  return $self->push(@elements);
}

sub merge {
  my ($self, $other) = @_;
  
  $self->{_dirty} = 1;
  
  return $self->push($other->elements);
}

sub del {
  my ($self, @patterns) = @_;

  my @result;
  my ($i, $element);

  # do nothing if the list is empty
  unless ($self->size > 0) {
    return $self;
  };

  # If first list element is a scalar
  if (not ref @{$self->list}[0]){
    return ($self->set(grep {not /^$patterns[0]$/} @{$self->list}));
  };

  # If first list element is an array
  if (ref @{$self->list}[0] eq 'ARRAY') {
  ELEMENT: foreach $element (@{$self->list}) {
      for ($i=0; $i <= $#patterns; $i++) {
	if ($patterns[$i]  && ($$element[$i] !~ /^$patterns[$i]$/)){
	  CORE::push (@result, $element);
	  next ELEMENT;
	}
      }
    };
    return $self->set(@result);
  };
  
  # An undefined data type

  carp "del is currently not implemented for elements of type " . ref @{$self->list}[0];
  return undef;
}
 
# Only maintained for backward compatibility
sub mdel {
  my ($self, @elements) = @_;

  carp "mdel is deprecated. Please use del instead\n";

  return $self->del(@elements);
}

sub sort {
  my ($self, $coderef) = @_;
  
  if ($coderef) {
    return $self->set(sort $coderef @{$self->list});
  }
  else {
    return $self->set(sort @{$self->list});
  }
}

# make sure that an object is only contained once in a list.
sub unique {
  my ($self) = @_;

  my @result = ();
  my @old = @{$self->list};
  my ($arg, $pat);
  
  if ($#old > -1) {
    # list is not empty, delete duplicates
    $self->set(@{$self->list}[0]);
    
    foreach $arg (@old) {
      # The list elements might have Perl regexp wildcards.
      # These must be quoted in the search pattern.
      if (not ref $arg) {
	$pat = quotemeta $arg
      }
      elsif (ref $arg eq 'ARRAY') {
	$pat = [map {quotemeta $_} @$arg];      
      };
      
      # save the element if it's not yet there
      unless ($self->get($pat)) {
	$self->push($arg);
      };
    }
  }
  return 1;
}

sub update {
  my ($self, $force) = @_;

  $self->sort();

  return 1;
}

# Return a new ListBase object which contains all elements for which
# the filter function returns true.
sub filter {
  my ($self, $filterFunc) = @_;

  my @matches = ();
  my $element;
  
  foreach $element ($self->elements()) {
    (&$filterFunc($element)) && (CORE::push(@matches, $element));
  };

  my $new = new ref($self);
  $new->set(@matches);
  $new->{indentation} = $self->{indentation};
  
  return $new;
};

# Examples for filter functions which might be used by ListBase::filter
sub attributeDefined {
  _attributeDefined(@_);
}

sub attributeEquals {
  _attributeEquals(@_);
}

sub attributeMatchedBy {
  _attributeMatchedBy (@_);
}

sub _attributeDefined{
  my $attributeName = CORE::shift();
  return sub {
     my $self = CORE::shift();

     return (defined $self->{$attributeName});
   }
}

sub _attributeEquals{
  my ($attributeName, $target) = @_;

  return sub {
     my $self = CORE::shift();

     return ($self->{$attributeName} eq $target);
   }
}

sub _attributeMatchedBy{
  my ($attributeName, $target) = @_;

  return sub {
     my $self = CORE::shift();

     return ($self->{$attributeName} =~ /$target/);
   }
}

# Return a new ListBase object. Each of the elements of the new object
# matches the parameter list of the method.
sub getObject {
  my ($self, @elements) = @_;

  my $new = new ref($self);

  $new->set($self->get(@elements));

  return $new;
};


# Evidence tag handling
sub evidenceTagPosition { 
# find index of evtag in an array "object" (e.g. a FT: [ key, from, to, text, qualifier, ftid, isoform, evidenceTags ] evtag index is 7)
  my ($arrayP) = @_;
  if ($#$arrayP == -1) {
    return 0;
  }
  # generaly is last element
  if (@$arrayP[$#$arrayP] eq '{}') { return $#$arrayP; } # recognizable empty ev in last elem
  elsif (@$arrayP[$#$arrayP] =~ $SWISS::TextFunc::evidencePattern) { # ev in last elem
    return $#$arrayP;
  } else { # not found in last element = array has yet no evtag, evtag should be added after end of array, index = 1 outside array (= array size)
    return $#$arrayP+1;
  }
}

sub setEvidenceTags {
  my ($self, $arrayP, @tags) = @_;

  unless (ref $arrayP eq 'ARRAY') {
    confess "$arrayP is not an array\n";
  }
  my $evidenceTagPosition = evidenceTagPosition($arrayP);
  my $is_new = grep { /ECO:/ } @tags;
  my $joiner = $is_new ? ', ' : ',';
  @$arrayP[$evidenceTagPosition] = ( $is_new ? ' ' : '' ) . '{' . (join ', ', @tags) . '}';

  $self->{_dirty} = 1;
  
  return $arrayP;
}

sub addEvidenceTag {
  my ($self, $arrayP, $tag) = @_;

  unless (ref $arrayP eq 'ARRAY') {
    confess "$arrayP is not an array\n";
  }

  my $evidenceTagPosition = evidenceTagPosition($arrayP);
  my $evidenceTagPointer = \@$arrayP[$evidenceTagPosition];

  # initialise $$evidenceTagPointer
  unless ($$evidenceTagPointer) {
    $$evidenceTagPointer = '{}';
  }
  
  my $is_new_format = $tag =~ /ECO:/;
  
  unless ($$evidenceTagPointer =~ /[\{\,] ?\Q$tag\E[\}\,]/) {
    if ((!$$evidenceTagPointer)
	||
	($$evidenceTagPointer eq '{}')) {
      $$evidenceTagPointer = ( $is_new_format ? ' ' : '' ) . '{' . $tag . '}';
    } else {
      $$evidenceTagPointer =~ s/\{/ {/ if $is_new_format && $$evidenceTagPointer =~ /^\{/;
      if ( $is_new_format ) { $$evidenceTagPointer =~ s/\}/\, $tag\}/; } else { $$evidenceTagPointer =~ s/\}/\,$tag\}/; }  
    }
  }
  $self->{_dirty} = 1;
  
  return $arrayP;
}

sub deleteEvidenceTag {
  my ($self, $arrayP, $tag) = @_;

  unless (ref $arrayP eq 'ARRAY') {
    confess "$arrayP is not an array\n";
  }

  my $evidenceTagPosition = evidenceTagPosition($arrayP);
  my $evidenceTagPointer = \@$arrayP[$evidenceTagPosition];
  
  $$evidenceTagPointer =~ s/([\{\,] ?)\Q$tag\E([\,\}])/$1$2/;
  $$evidenceTagPointer =~ s/\, ?\,/\,/;
  $$evidenceTagPointer =~ s/\, ?\}/\}/;
  $$evidenceTagPointer =~ s/\{\, ?/\{/;
  $$evidenceTagPointer =~ s/ ?\{\}//;
  
  if ( ! $$evidenceTagPointer ) { delete $arrayP->[ $evidenceTagPosition ]; }

  $self->{'_dirty'} = 1;

  return $arrayP;
}

sub hasEvidenceTag {
  my ($self, $arrayP, $tag) = @_;

  unless (ref $arrayP eq 'ARRAY') {
    confess "$arrayP is not an array\n";
  }

  my $evidenceTagPosition = evidenceTagPosition($arrayP);
  
  return @$arrayP[$evidenceTagPosition] =~ /[\{\,] ?\Q$tag\E[\}\,]/;
}

sub getEvidenceTags {
  my ($self, $arrayP, $tag) = @_;

  unless (ref $arrayP eq 'ARRAY') {
    confess "$arrayP is not an array\n";
  }

  my $tmp =  @$arrayP[evidenceTagPosition($arrayP)];
  $tmp =~ tr/\{\}//d;
  return map { s/^ +//; $_ } split /\,/, $tmp;
}

sub getEvidenceTagsString {
  my ($self, $arrayP, $tag) = @_;

  unless (ref $arrayP eq 'ARRAY') {
    confess "$arrayP is not an array\n";
  }

  my $tmp =  @$arrayP[evidenceTagPosition($arrayP)] || '';

  if ($tmp eq '{}') {
    return '';
  } else {
    return $tmp;
  }
}

# return the intersection with another list 
# usage: @myary = $mylistbase->intersect(@otherary);
#    or  @myary = $mylistbase->intersect($otherlistbase);
sub intersect {
  my ($self, @other) = @_;

  # if argument is another ListBase, get its contents into @other
  my $arg = $other[0];
  if ($arg && ref($arg) eq ref($self)){
    warn "ListBase::intersect doesnt allow two ListBases as input\n"
      if $main::opt_warn && $#other>0;
    @other = @{$arg->list};
  }

  my %other_hash = map {$_,1} @other;  
  my @result = grep { $other_hash{$_}} @{$self->list};
  return @result;
}

# return the union with another list 
# usage: @myary = $mylistbase->union(@otherary,...);
#    or  @myary = $mylistbase->union($otherlistbase,...);
sub union {
  my ($self, @args) = @_;

  my @other = @{$self->list};
  my $arg;

  foreach $arg (@args){
    my $kind = ref $arg;
    if (not $kind){
      CORE::push(@other,$arg);
    } elsif ($kind eq ref($self)){
      CORE::push(@other, @{$arg->list});
    } elsif ($kind eq 'SCALAR'){
      CORE::push(@other, $$arg);
    } elsif ($kind eq 'ARRAY'){
      CORE::push(@other, @$arg);
    } elsif ($kind eq 'HASH'){
      CORE::push(@other, keys %$arg);
    }
  }
   
  my %result_hash = map {$_,1} @other, @{$self->list}; 
  return keys %result_hash;
}


# return myself minus another list
# usage: @myary = $mylistbase->minus(@otherary);
#    or  @myary = $mylistbase->minus($otherlistbase);
sub minus {
  no strict 'refs';
  my ($self, @other) = @_;

  # if argument is another ListBase, get its contents into @other
  my $arg = $other[0];
  my $ref = ref($arg);
  if ($ref && $ref->isa('SWISS::ListBase') ){
    warn "ListBase::minus doesnt allow two ListBases as input\n"
      if $main::opt_warn && $#other>0;
    @other = @{$arg->list};
  }

  my %other_hash = map {$_,1} @other;
  
  my @result = grep { !$other_hash{$_}} @{$self->list};
  return @result;
}

# compare self to another list
# returns  0 if both lists are equal,
#         -1 if self is subset of the argument
#          1 if the argument is a subset of self
#          2 if both list are unequal
sub cmp {
  my ($self, @set_b) = @_;

  my @set_a  = @{$self->list};
  
  my %hash_a = map {$_,1} @set_a;
  my %hash_b = map {$_,1} @set_b;

  my @aminusb =  grep { !$hash_b{$_}} @set_a;
  my @bminusa =  grep { !$hash_a{$_}} @set_b;

  if (@aminusb){
    if (@bminusa){
      return  2;
    } else {
      return  1; 
    }
  } else {
    if (@bminusa){
      return -1;
    } else {
      return  0;
    }
  }
}

1;

__END__

=head1 Name

SWISS::ListBase.pm

=head1 Description

Base class for list oriented classes in the SWISS:: hierarchy. It provides a set of quite general list manipulation methods to inheriting classes. 

=head1 Attributes

=over

=item list

Holds an array, the essential content of the object. Array elements can be, and are in fact frequently, arrays themselves.

=back

=head1 Methods 

=head2 Standard methods

=over

=item new

=item initialize

=back

=head2 Reading methods

=over

=item head

Return the first element of the list

=item tail

Return all but the first element of the list

=item get pattern

Return a list of all elements matched by $pattern. Only exact matches are returned, but you can use Perls regular expressions. Example:

  $listBaseObject->set('EMBL', 'TREMBL', 'SWISSPROT'); 
  $listBaseObject->get('.*EMBL'); 

returns ('EMBL', 'TREMBL') 

=item get @patternList 

To be used if the ListBase elements are arrays. An array is returned if all its elements are matched exactly by the elements from @patternList with the same index. Empty elements in @patternList always match. Example: 

 $listBaseObject->set(['EMBL', 'M1', 'G1', '-'],
                      ['EMBL', 'M2', 'A2', '-'],
                      ['EMBL', 'M2', 'G3', 'ALT_TERM'],
                      ['PROSITE', 'P00001', '1433_2', '1']);
 $listBaseObject->get('EMBL');

 returns (['EMBL', 'M1', 'G1', '-'],
          ['EMBL', 'M2', 'A2', '-'],
          ['EMBL', 'M2', 'G3', 'ALT_TERM'])
 
 $listBaseObject->get('',M2);

 returns (['EMBL', 'M2', 'A2', '-'],
          ['EMBL', 'M2', 'G3', 'ALT_TERM']);

Offering get in the interface is not particularly nice because it exports implementation details into the interface, but it is a powerful method which may save a lot of programming time. As an alternative, the 'filter' concept is available. 

=item getObject pattern

=item getObject @patternList

Same as get, but returns the results wrapped in a new ListBase object.

=item filter

Returns a new object containing all of the elements that match a search criteria. It takes a function as the only parameter. This function should expect a list element, and return true or false depending on whether the element matches the criteria. If the object is not a ListBase object but member of a subclass, a new object of that subclass will be returned.  

Example:

 $tmp = $entry->CCs->filter(&ccTopic('FUNCTION')); 

returns a SWISS::CCs object containing all CC blocks from $entry which have the topic 'FUNCTION'. 

Functions can also be anonymous functions. 

=item attributeEquals(string attributeName, string attributeValue)

Filter function. If the elements of a ListBase object are objects, they will be returned by this function if they have the attribute and it equals the attributeValue.

 Example:

$matchedKWs = $entry->KWs->filter(SWISS::ListBase::attributeEquals('text', $kw));

=item attributeMatchedBy(string attributeName, string pattern)

Filter function. If the elements of a ListBase object are objects, they will be returned by this function if they have the attribute and the attribute is matched by the pattern.

 Example:

$matchedKWs = $entry->KWs->filter(SWISS::ListBase::attributeMatchedBy('text', $kw));

=item isEmpty

=item size

The number of list elements in the object

=item elements

Returns the array of elements 

=item hasEvidenceTag $arrayPointer $tag

Returns true if the array pointed to by $arrayPointer has the evidence tag $tag

=item getEvidenceTags $arrayPointer

returns the array of evidence tags of $arrayPointer

=item getEvidenceTagsString $arrayPointer

returns a string containing the evidence tags of $arrayPointer

=back

=head2 Writing methods

=over

=item item offset[, newValue]

returns the list element at a specific offset, and optionally sets it to a new value. Negative offsets are relative to the end of the list.

=item push list

=item pop

=item shift

=item unshift list

=item splice [offset[, length[, list]]]

=item set list

Sets the list attribute to @list

=item add list

Synonym for push

=item merge (ListBase)

Appends the elements of ListBase to the object

=item sort [function]

Applies a sort function to the list attribute, or by default, alphabetical sorting. Should be overwritten in derived classes with an adapted sort function. 

=item del pattern 

Deletes all items fully matching $pattern. Example:

  $listBaseObject->set('EMBL','TREMBL', 'SWISSPROT');
  $listBaseObject->del('EMBL');

  $listBaseObject->list();

  returns ('TREMBL','SWISSPROT').

If you want to delete more, use something like

  $listBaseObject->del('.*EMBL')

which deletes 'EMBL' and 'TREMBL'.

=item del @patternList

To be used if the ListBase objects are arrays. An array is deleted if all its elements are matched by the elements from @patternList with the same index. 

B<Warning: Empty elements in @patternList always match!>

Using the data from the get example above, 

  $listBaseObject->del('','', 'A2') 

results in 

  (['EMBL', 'M1', 'G1', '-'],
   ['EMBL', 'M2', 'G3', 'ALT_TERM'],
   ['PROSITE', 'P00001', '1433_2', '1'])

=item update

=item unique

Makes sure each element is contained only once in a ListBase object. The second and subsequent occurrences of the same object are deleted. Example:

  $listBaseObject->set(EMBL, TREMBL, SWISSPROT);
  $listBaseObject->add(EMBL, MGD, EMBL);
  $listBaseObject->unique();

results in (EMBL, TREMBL, SWISSPROT, MGD) 

=item setEvidenceTags $arrayPointer @array

sets the evidence Tags of the array pointed to by $arrayPointer to the contents of @array 

To be used if the ListBase elements are themselves arrays. A typical construct would be

  foreach $dr ($entry->DRs->elements()) {
    $entry->DRs->setEvidenceTags($dr, 'E2', 'E3');
  }


Returns $arrayPointer.

=item addEvidenceTag $arrayPointer $tag

adds $tag to the evidence tags of $arrayPointer

To be used if the ListBase elements are themselves arrays. See documentation of setEvidenceTags.

Returns $arrayPointer.

=item deleteEvidenceTags $arrayPointer $evidenceTag

deletes $evidenceTag from the array pointed to by $arrayPointer

To be used if the ListBase elements are themselves arrays. A typical construct would be

  foreach $dr ($entry->DRs->elements()) {
    $entry->DRs->deleteEvidenceTags($dr, 'EC2');
  }

Returns $arrayPointer.

=back
