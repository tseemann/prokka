package SWISS::GNs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::GeneGroup;
use Data::Dumper;

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');
  
  %fields = (
	and => " AND ",
	or  => " OR " ,
	    );
}

sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::ListBase;
  
  $self->rebless($class);
  return $self;
}

sub initialize {
}

sub fromText {
  my $self = new(shift);
  my $textRef = shift;
  my $line = '';
  my @tmp;
 
  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'GN'})/m){ 
    $line = join ' ', map {
      $self->{indentation} += $_ =~ s/^ //;
      SWISS::TextFunc->cleanLine($_);
      } (split /\n/m, $1 );  
    $line =~ s/\.$//;
  }
  $self->text($line);
  return $self;
}

sub is_old_format {
  my $self = shift;
  if (@_) {
  map {$_->is_old_format(@_)} $self->elements;
  }
  else  {
  return grep {$_->is_old_format} $self->elements;
  }
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  if ($self->is_old_format) {
    $self->is_old_format(1);
    return _toText_old($self, $textRef, @_);
  }
  $self->is_old_format(0);
  my $newText = '';
    my @groups;
    for my $group (@{$self->list}) {
    my $groupText = $group->toText;
    my $prefix = "GN   ";
    my $col = $SWISS::TextFunc::lineLength;
    $col++, $prefix=" $prefix" if $self->{indentation};
    push @groups, SWISS::TextFunc->wrapOn($prefix, $prefix, $col,
  			         $groupText, 
  			         ';\s+', ',\s+', '\s+');
  }
  my $indent = $self->{indentation} ? " " : "";
  $newText = join "${indent}GN   and\n", @groups;
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'GN'});
}

sub _toText_old {
  my $self = shift;
  my $textRef = shift;
  my $newText = '';
  if ($self->size){
    $newText = $self->text;
    return $textRef if !defined $newText;
    $newText .= ".";

    #wrapping rules : 
    # - whenever possible, wrap after AND.
    # - else, wrap before or after an OR or AND, so as to maximize the length of
    #   the uppermost line.

    my $or = $self->or; my $and = $self->and;
    for ($or,$and) { s/^\s+//; s/\s+$//; $_ = quotemeta $_; }
    my $pat = "(?<= $or )|(?<= $and )| (?=$or |$and )";
    my $prefix = "GN   ";
    my $col = $SWISS::TextFunc::lineLength;
    $col++, $prefix=" $prefix" if $self->{indentation};
    $newText = SWISS::TextFunc->wrapOn($prefix, $prefix, $col,
				       $newText, 
				       "\\s+$and\\s+", $pat, ',\s+', '(?=\()', '\s+');
  };
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'GN'});
}

sub text {
  my $self = shift;
  my $text = shift; 
  if (defined $text) {
    #reset GNs object from $text

    my $sep = $text =~ /^ *(?:Name|Synonyms|OrderedLocusNames|ORFNames)=/ ? "; and " : " and ";
    @{$self->list} = map {SWISS::GeneGroup->fromText($_)} split /$sep/i, $text;
    $self->{and} = $1 if $text =~ /( AND )/i;
    $self->{or} = $1 if $text =~ /( OR )/i;
    $self->{_dirty} = 0;
    if (defined $main::opt_gn_check) {     
      if ($text ne $self->text) {
        print STDERR "Warning: SWISS::GNs->text could not interpret the following line : \n".
          "$text\nDo not define \$main::opt_gn_check to remove this message.\n";
      }
    }
    return $text;
  }
  else {
    #simply return text
    @{$self->list} = grep {$_->size} @{$self->list};
    my $addParen = $self->size>1;
    return undef unless $self->size;
    return join $self->and, map {
      my $a=$_->_toText_old($self->or);
      $a="($a)" if $addParen && @{$_->list}>1;
      $a } @{$self->list};
  }
}

sub update {
  my $self = shift;
  my $force = shift;                  # force update 

  if ($force) {
    
    # make sure that GN line is deleted on update if GN object has no gene names
    
    @{$self->list} = grep {$_->size} @{$self->list};
    return undef unless $self->size;
  } 
  $self->sort();
  
  return 1;
}

sub sort {
  my $self = shift;
  return map {$_->sort(@_)} @{$self->list};
}

sub get {
  my $self = shift;
  return map {$_->get(@_)} @{$self->list};
}

sub lowercase {
  my $self = shift;
  $self->{and}=~tr/A-Z/a-z/;
  $self->{or}=~tr/A-Z/a-z/;
}

sub uppercase {
  my $self = shift;
  $self->{and}=~tr/a-z/A-Z/;
  $self->{or}=~tr/a-z/A-Z/;
}

sub getFirst {

  my ($self) = @_;

  if ($self->is_old_format) {

    for my $ggroup ($self->elements) {

      return ${$ggroup->list}[0]->text;
    }
  
  } else {
  
    for my $ggroup (@{$self->list}) {
  	  
      return ${$ggroup->list()}[0] -> text();
    }
  }
}

sub getTags {

  # return evidnece tags associated with a given gene name

  my ($self, $target) = @_;

  if ($self->is_old_format) {
  
    for my $ggroup ($self->elements) {

      for (my $n=0;$n<$ggroup->size;$n++) {
    
        if (${$ggroup->list}[$n]->text eq $target) {
      
          return ${$ggroup->list}[$n]->getEvidenceTags;
        }
      }
    }
  
  } else {
  
    for my $ggroup (@{$self->list}) {
    
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        if (${$ggroup->list()}[$n] -> text() eq $target) {
      
          my $tags = ${$ggroup->list()}[0] -> evidenceTags();
          $tags =~ s/{|}|,//g;
          return $tags;
        }
      }
    }
  }
  
  return;
}

sub isPresent {

  # method to identify whether a given name is present in the GN object

  my ($self, $target) = @_;
  
  if ($self->is_old_format) {
  
    my ($self, $target) = @_;

    for my $ggroup ($self->elements) {

      for (my $n=0;$n<$ggroup->size;$n++) {
    
        if (${$ggroup->list}[$n]->text eq $target) {
      
          return 1;
        }  
      }
    }
  
  } else {
  
    for my $ggroup (@{$self->list}) {
    
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        if (${$ggroup->list()}[$n] -> text() eq $target) {
      
          return 1;
        }
      }
    }
  }
  
  return;
}


sub needsReCasing {

  # method to identify whether a given name is present in the GN object, but 
  # not in mixed case
  
  # returns match in current state

  my ($self, $target) = @_;
  
  if ($self->is_old_format) {
  
    for my $ggroup ($self->elements) {

      for (my $n=0;$n<$ggroup->size;$n++) {
    
        my $existingName = ${$ggroup->list}[$n]->text;
      
        if ((uc $existingName eq uc $target) &&
            ($existingName ne $target)) {
      
          return $existingName;
        }
      }
    }
  
  } else {
  
    for my $ggroup (@{$self->list}) {
    
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        my $existingName = ${$ggroup->list()}[$n] -> text(); 
      
        if ((uc $existingName eq uc $target) && ($existingName ne $target)) {
           
          return $existingName;
        } 
      }
    }
  }
  
  return;
}

sub replace {

  # replaces the first occurance of a given gene name in a GN line with the
  # replacement name.
  
  my ($self, $newName, $target, $evidenceTag) = @_;

  # no safety check: allow for adding identical names (tag addition)
  
  if ($self->is_old_format) {
  
    for my $ggroup ($self->elements) {
  
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        my $geneText = ${$ggroup->list}[$n]->text;
          
        if ($geneText eq $target) {
          
           ${$ggroup->list}[$n]->text($newName);
         
           # may want to keep old evidence tags when replacing, i.e. add > 1
         
           my @tags = split /, /, $evidenceTag;
           ${$ggroup->list}[$n] -> setEvidenceTags(@tags);
           return;
        }
      }
    }
  
  } else {
  
    for my $ggroup (@{$self->list}) {
    
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        my $name = ${$ggroup->list()}[$n]; 
    
        if ($name -> text() eq $target) {
  
          $name -> text($newName);           
          my @tags = split /, /, $evidenceTag;
          $name -> setEvidenceTags(@tags);
          return;
        }
      }
    }
  }
  
  return;   
}

sub delete {

  my ($self, $target) = @_;
  my $groupCount = 0;
  
  if ($self->is_old_format) {
  
    for my $ggroup ($self->elements) {
  
      for (my $n=0;$n<$ggroup->size;$n++) {
    
        my $geneText = ${$ggroup->list}[$n]->text;
      
        if ($geneText eq $target) {
      
          if ($ggroup->size == 0) {
        
            # remove gene group
          
            splice (@{$self->list}, $groupCount, 1);
          
          } else {
        
            # remove synonym from group
          
            splice (@{$ggroup -> list}, $n, 1);
          }
        
          return;
        }
      }
      
    $groupCount++;
    
    }
  
  } else {
  
    for my $ggroup ($self->elements) {
    
      CHECK: for (my $nameSet = 0; $nameSet < 3; $nameSet ++) {
        
        my @names;
        
        if ($nameSet == 0) {
        
          @names = $ggroup->Names->elements();
        
        } elsif ($nameSet == 1) {
          
          @names = $ggroup->OLN->elements();
          
        } else {
          
          @names = $ggroup->ORFNames->elements();
        }
        
        for (my $n=0;$n<scalar @names;$n++) {
      
          my $name = $names[$n]; 
    
          if ($name -> text() eq $target) {
          
            if ($ggroup->size == 0) {
        
              # remove gene group
          
              splice (@{$self->list}, $groupCount, 1);
          
            } else {
        
              # remove synonym from group
          
              splice (@names, $n, 1);
              
              if ($nameSet == 0) {
              
                @names = $ggroup->Names->list([@names]);
              
              } elsif ($nameSet == 1) {
              
                @names = $ggroup->OLN->list([@names]);
              
              } else {
              
                @names = $ggroup->ORFNames->list([@names]);
              }
              
              last CHECK;
            }
          }
        }
      }
    }
  }  
  
  return;  
}  

sub addAsNewSynonym {

  # user should first check that target exists using 'isPresent'.  If target is 
  # not found, method does nothing
  
  # otherwise method either adds new name in the gene group containing the
  # target, according to the parameter specified in $location

  # location > 1: insert name in first, second, third position etc.
  # location = 0: insert name before target
  # location = -1: insert name after target (default)
  # location = -2: insert name at end of gene group

  my ($self, $newName, $target, $evidenceTag, $location) = @_;

  # safety check: don't add duplicate gene names
  
  if (isPresent($self, $newName)) {
  
    return;
  } 

  if ($location eq '') {
  
    $location = -1;
  }
  
  my $GN = SWISS::GN -> new();
  $GN -> text($newName);
  $GN -> addEvidenceTag($evidenceTag);
  
  if ($self->is_old_format) {
    
    GENEGROUPS: for my $ggroup ($self->elements) {
  
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        my $geneText = ${$ggroup->list}[$n]->text;
          
        if ($geneText eq $target) {
      
          my $position;
        
          if ($location == 0) {
        
            $position = $n;
              
          } elsif ($location == -1) {
          
            $position = $n + 1;
              
          } elsif ($location == -2) {
            
             $position = $ggroup->size;
        
          } else {
        
            $position = $location - 1;
          }
          
          splice @{$ggroup->list}, $position, 0, $GN;
          last GENEGROUPS;
        }
      }
    }
  
  } else {
  
    GENEGROUPS: for my $ggroup ($self->elements) {
    
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        my $name = ${$ggroup->list()}[$n]; 
    
        if ($name -> text() eq $target) {
          
          my $position;
        
          if ($location == 0) {
        
            $position = $n;
              
          } elsif ($location == -1) {
          
            $position = $n + 1;
              
          } elsif ($location == -2) {
            
             $position = $ggroup->size;
        
          } else {
        
            $position = $location - 1;
          }
          
          splice @{$ggroup->list}, $position, 0, $GN;
          last GENEGROUPS;
        }
      }
    }
  }
  
  return;
}

sub addAsNewGeneGroup {

  # method adds a new gene name in a new gene group, $target and $location can 
  # be used to specify where in line new group should go
  
  # otherwise method either adds new name in the gene group containing the
  # target, according to the parameter specified in $location

  # location > 1: insert group in first, second, third position etc.
  # location = 0: insert group before group containing target
  # location = -1: insert group after group containing target (default)
  # location = -2: insert group at end

  # note that 'addSynonym requires a target to be specified (always).  
  # 'addAsNewGeneGroup' only requires a target if $location is 0 or -1

  my ($self, $newName, $target, $evidenceTag, $location) = @_;
  
  # safety check: don't add duplicate gene names
  
  if (isPresent($self, $newName)) {
  
    return $self;
  } 

  if ($location eq '') {
  
    $location = -1;
  }
  
  my $match = 0;
  my $position;
  my $GN = SWISS::GN -> new();
  $GN -> text($newName);
  $GN -> addEvidenceTag($evidenceTag);
  my $newGeneGroup = SWISS::GeneGroup -> new();
  
  if ($self->is_old_format) {
  
    push @{$newGeneGroup -> list}, $GN;
  
  } else {
  
    push @{$newGeneGroup -> list}, $GN;
  }
  
  if ($location < 1) {
  
    if ($location == -2) {
     
      $position = $self -> size();
      $match++;
    
    } else {
    
      my $p = 0;
      $p = -1;
      
      if ($self->is_old_format) {
      
        GENEGROUPS: for my $ggroup ($self->elements) {
  
          $p++;
        
          for (my $n=0;$n<$ggroup->size;$n++) {
        
            my $geneText = ${$ggroup->list}[$n]->text;
          
            if ($geneText eq $target) {
      
              if ($location == 0) {
        
                $position = $p;
              
              } elsif ($location == -1) {
          
                $position = $p + 1;
              }
            
              $match++;
              last GENEGROUPS;
            }
          }
        }
        
      } else {
      
        GENEGROUPS: for my $ggroup ($self->elements) {
  
          $p++;
        
          for (my $n=0;$n<$ggroup->size;$n++) {
        
            my $geneText = ${$ggroup->list}[$n]->text;
          
            if ($geneText eq $target) {
      
              if ($location == 0) {
        
                $position = $p;
              
              } elsif ($location == -1) {
          
                $position = $p + 1;
              }
            
              $match++;
              last GENEGROUPS;
            }
          }
        }
      }
    }
  
  } else {
  
    $position = $location  - 1;
    $match++;
  }
  
  if ($match == 1) {
  
    splice @{$self -> list}, $position, 0, $newGeneGroup;
  }
  
  return;
}

sub replaceGeneGroup {

  # replaces the first gene group containing $target with the gene group
  # supplied as a paramter

  my ($self, $newGeneGroup, $target) = @_;
  my $groups = 0;
  my $hit    = 0;
  my $thisGroup;

  if ($self->is_old_format) {
  
    GENEGROUPS: for my $ggroup ($self->elements) {
  
      $groups++;
  
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        my $geneText = ${$ggroup->list}[$n]->text;
          
        if ($geneText eq $target) {
      
          $thisGroup = $groups;
          $hit++;
          last GENEGROUPS;
        }
      }
    }
  
  } else {
  
    GENEGROUPS: for my $ggroup ($self->elements) {
    
      $groups++;
      
      for (my $n=0;$n<$ggroup->size;$n++) {
      
        my $geneText = ${$ggroup->list}[$n]->text;
  
        if ($geneText eq $target) {
      
          $thisGroup = $groups;
          $hit++;
          last GENEGROUPS;
        }
      }
    }
  }
  
  if ($hit > 0) {
  
    splice @{$self -> list}, $thisGroup -1, 1, $newGeneGroup;
  }
}

sub getGeneGroup {
 
  my ($self, $target) = @_;
  
  GENEGROUPS: for my $ggroup ($self->elements) {
  
    for (my $n=0;$n<$ggroup->size;$n++) {
      
      my $geneText = "";
      
      if ($self->is_old_format) {
      
        $geneText = ${$ggroup->list}[$n]->text;
      
      } else {
      
        $geneText = ${$ggroup->list}[$n]->text;
      }
          
      if ($geneText eq $target) {
      
        return $ggroup;
      }
    }
  }
}

sub setToOr {

  # needed when adding C to 'A AND B', when the realtionship of C to A and B is
  # unknown: ' or ' os the default setting

  my ($self) = @_;
  my $GNs = SWISS::GNs -> new();
  my $geneGroup = SWISS::GeneGroup -> new();
  
  # maintain 'and' and 'or' values
  
  $GNs -> or($self -> or());
  $GNs -> and($self -> and());
  
  for my $ggroup ($self->elements) {
 
    for (my $n=0;$n<$ggroup->size;$n++) {
        
       push @{$geneGroup -> list}, ${$ggroup->list}[$n];
    }
  }
  
  push @{$GNs -> list}, $geneGroup;
  
  return $GNs;
}

1;

__END__

=head1 Name

SWISS::GNs.pm

=head1 Description

B<SWISS::GNs> represents the GN lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
 http://www.expasy.org/sprot/userman.html . The GNs object is a 
container object which holds a list of SWISS::GeneGroup objects.

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

  Each list element is a SWISS::GeneGroup object.

=item C<and> I<(deprecated, for old format only)>

  Delimiter used between genes. Defaults to " AND ".

=item C<or> I<(deprecated, for old format only)>

  Delimiter used between gene names. Defaults to " OR ".

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head2 Reading/Writing methods

=over

=item text [($newText)]

Sets the text of the GN line to the parameter if it is present, and returns
the (unwrapped) text of the line.  Also sets 'and' and 'or' delimiters to 
the first occurrences of the words "OR" and "AND" in the line, conserving
the case.

=item lowercase I<(deprecated, for old format only)>

Sets the GNs::and and GNs::or delimiters to their lower case
values.

=item uppercase I<(deprecated, for old format only)>

Sets the GNs::and and GNs::or delimiters to their upper case
values.

=item getFirst()

Returns first gene name in gene line

=item getTags($target)

Returns evidence tags associated with $target

$target is a string

=item isPresent($target)

Returns 1 if $target is present in the GN line

$target is a string

=item needsReCasing($target)

If $target is present in the GN line, but wrongly cased, method returns the
matching name in its current case

$target is a string

=item replace($newName, $target, $evidenceTag)

Replaces the first GN object in the GN line whose text attribute is $target with
a new GN object whose text attribute is set to $newName and whose evidenceTags
attribute is is set using values set by splitting $evidenceTag on /, / (as name
is not being changed, programs should keep old tag and add new tag).  Does 
nothing if $target is not found. 

=item delete($target)

Removes synonym/single-member gene group matching $target. Note that if a "Name" 
is deleted, the first "Synonym" will be promoted to "Name"

=item addAsNewSynonym($newName, $target, $evidenceTag, $location)

Adds a new GN object (with text attribute set to new $newName, and evidenceTags
attribute set to ($evidenceTag)), as a synonym to the first gene group in which
$target is a gene name.  Does nothing if $target is not found.  Will not add a
duplicate gene name.  $location determines where in gene group new object is
added: if $location == 1, 2, 3, ..., new object added in the 1st, 2nd, 3rd, ... 
position; if $location == 0, new object added before $target; if $location
== -1, new object added after $target (default); if $location == -2, new object
added at end of gene group.  Note that if the new synonym is inserted in the 
first postion, it will become the "Name" and the previous "Name" will be downgraded
to first "Synonym"

=item addAsNewGeneGroup($newName, $target, $evidenceTag, $location)

Adds a new GeneGroup object, comprising 1 GN object (with text attribute set to
new $newName, and evidenceTags attribute set to ($evidenceTag)). Will not add a
duplicate gene name.  $location and $target determine where in GNs line new 
group is added: if $location == 1, 2, 3, ..., new object added in the 1st, 2nd,
3rd, ... position; if $location == 0, new object added before $target; if
$location == -1, new object added after $target (default); if $location == -2,
new object added at end of GNs line.  Does nothing if $target is not found, and
$location == 0 or -1; otherwise $target does not need to be set.

=item replaceGeneGroup($newGeneGroup, $target)

Replaces the first gene group containing $target with $newGeneGroup.  Creating
the $newGeneGroup correctly is the user's responsibility

=item getGeneGroup($target)

Returns the first gene group that contains $target

=item setToOr()

Retruns a new GNs object, but with all GNs objects in a single gene group.  
Needed when adding 'C' to 'A and B', when the relationship of 'C' to 'A' and 
'B' is unknown: the universal use of ' or ' is the default delimeter for TrEMBL 
entries

=back

=head1 TRANSITION

The format of the GN line will change in 2004 from:

 GN   (CYSA1 OR CYSA OR RV3117 OR MT3199 OR MTCY164.27) AND (CYSA2 OR
 GN   RV0815C OR MT0837 OR MTV043.07C).

to:

 GN   Name=CysA1; Synonyms=CysA; OrderedLocusNames=Rv3117, MT3199;
 GN   ORFNames=MtCY164.27;
 GN   and
 GN   Name=CysA2; OrderedLocusNames=Rv0815c, MT0837; ORFNames=MTV043.07c;

This module supports both formats. To convert an entry from the old to
the new format, do:

 $entry->GNs->is_old_format(0);
