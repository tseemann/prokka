package SWISS::BaseClass;

use vars qw($AUTOLOAD @ISA @EXPORT_OK);
use Exporter;
use Carp;
use strict;
use Data::Dumper;

# Place functions/variables you want to *export*, ie be visible from the caller package into @EXPORT_OK
@EXPORT_OK = qw();

use vars qw { @ISA $AUTOLOAD %fields };
 
BEGIN {
    # Our inheritance
    @ISA = ( 'Exporter' );

    # our data members
    %fields = (_dirty => undef,
	       evidenceTags => undef,
	       indentation => undef,
	      );
}
# makes it appear that there are functions 
# of the same names as the member variables
# which get and set their value
sub AUTOLOAD {
    my $name = $AUTOLOAD;
    $name =~ /::DESTROY/ && return;
    $name =~ s/.*://;

    my $self = shift;
    my $type = ref($self) || confess "Cannot use the non-object $self to find $name\n";

    unless (exists $self->{$name} ) {
        confess "In type $type, can't access $name.  Incorrect function or member name.\n";
	return undef;
    }
    if (@_) {
      # something is being set, so the object is dirty.
      $self->{_dirty} = 1;
      return $self->{$name} = shift;
    } else {
	return $self->{$name};
    }
}

# reblesses a reference to a base class object into your class
# adds the apropreate members with their default values as
# defined in the %fields hash, and modified by initialize
sub rebless {
  no strict 'refs';
  my $self = shift || confess "You must parse an object to rebless";
  my $class = shift || confess "You must give a package to rebless $self into";
  
  %{$self} = (%{$self}, %{$class."::fields"});
  bless $self, $class;
  $self->initialize();
  return $self;
}

# returns a myBase object
# use this for all derived classes
sub new {
    my $ref = shift;
    my $class = ref($ref) || $ref;
    my $self = {};
    
    rebless($self, $class);

    return $self;
}

# put any code that you want which initializes the virgin values of
# your member variables in here
sub initialize {
  my $self = shift;

  $self->{'evidenceTags'} = '{}';
  $self->{'indentation'} = undef;
  
  return $self;
}

sub update {
  my $self = shift;
  return $self;
}
  

# checks for name clashes between a class and all of it's base classes.
# Supports multiple inheritance, and multi-level inheritance
#
sub check4Clashes {
    no strict 'refs';
    my $class = shift;
    my @fields = keys %{$class."::fields"};
    my @parents = @{$class."::ISA"};
    my $parent;
    my $override;
    my @found = ();

    foreach $parent (@parents) {
	$override = ($parent->can('_containsFields') && $parent->_containsFields(@fields));
	$override && push @found, @$override;
    }

    if(@found) {
	confess "$class contains member variables that clash with base class members\n",
	map { "\t$_\n"} @found;
    }
}

# helper function for checkClashes
# less said about this the better
#
sub _containsFields {
    no strict 'refs';
    my $class = shift;
    my @fields = @_;
    my $field;
    my @parents = @{$class."::ISA"};
    my $parent;
    my $override;
    my @found = ();

    foreach $field (@fields) {
	if(exists ${$class."::fields"}{$field}) {
           push @found, $class."::".$field;
	}
    }

    foreach $parent (@parents) {
	$override = ($parent->can('_containsFields') && $parent->_containsFields(@fields));
	$override && push @found, @$override;
    }

    (@found) && return \@found;
    return undef;
}

# added by hhe@ebi.ac.uk
sub equal {
  my ($self, $other) = @_;

  return Dumper($self) eq Dumper($other);
};  

# Returns a "deep copy" of the object
sub copy {
  my $self = shift;
  my $new;

  eval Data::Dumper->Dump([$self], [qw(new *ary)]);
  return $new;
}

# Evidence tag handling
sub setEvidenceTags {
  my $self = shift;
  my @tags = @_;
  
  my $is_new = grep { /ECO:/ } @tags;
  my $joiner = $is_new ? ', ' : ',';
  $self->{'evidenceTags'} = ( $is_new ? ' ' : '' ) . '{' . (join $joiner, @tags) . '}'; # p.s. fugly: there is a space before { in new ev format: automatically add it depending if added tag is in new format!
  $self->{'_dirty'} = 1;
  return;
}

sub addEvidenceTag {
  my $self = shift;
  my $tag = shift;
  my $is_new_format = $tag =~ /ECO:/;
  my $actual_ev     = $self->{'evidenceTags'};
  unless ( $actual_ev =~ /[\{\,] ?\Q$tag\E[\}\,]/ ) { # add only if new
    if ($actual_ev eq '{}') {
      $self->{'evidenceTags'} = ( $is_new_format ? ' ' : '' ) . '{' . $tag . '}';
    } else {
      $self->{'evidenceTags'} =~ s/\{/ {/ if $is_new_format && $actual_ev =~ /^\{/;
      if ( $is_new_format ) { $self->{'evidenceTags'} =~ s/\}/\, $tag\}/; } else { $self->{'evidenceTags'} =~ s/\}/\,$tag\}/; } 
    } # p.s. fugly: there is a space before { in new ev format: automatically add it depending if added tag is in new format!
  }
  $self->{'_dirty'} = 1;
  return;
}

sub deleteEvidenceTag {
  my $self = shift;
  my $tag = shift;
  $self->{'evidenceTags'} =~ s/([\{\,] ?)\Q$tag\E([\,\}])/$1$2/;
  $self->{'evidenceTags'} =~ s/\, ?\,/\,/;
  $self->{'evidenceTags'} =~ s/\, ?\}/\}/;
  $self->{'evidenceTags'} =~ s/\{\, ?/\{/;
  $self->{'evidenceTags'} =~ s/ ?\{\}//;
  $self->{'_dirty'} = 1;
  return;
}

sub hasEvidenceTag {
  my $self = shift;
  my $tag = shift;
  return  $self->{'evidenceTags'} =~ /[\{\,] ?\Q$tag\E[\}\,]/;
}

sub getEvidenceTags {
  my $self = shift;
  my $tmp = $self->{'evidenceTags'};
  $tmp =~ tr/\{\}//d;
  return map { s/^ +//; $_ } split /\, ?/, $tmp;
}

sub getEvidenceTagsString {
  my $self = shift;
  my $tmp = $self->{'evidenceTags'};
    
  if ($tmp eq '{}') {
    return '';
  } else {
    return $tmp;
  }
}

# Force Swissknife to reformat an object, even if it has not been modified.
sub reformat {
  my $self = shift;
  $self->{_dirty} = 1;
}

1;

__END__

=head1 NAME

SWISS::BaseClass

=head1 DESCRIPTION

This class is designed to impliment many of the properties that you
expect in inheritance.  All the housekeeping functions are defined
in this module.  See the notes on use for a description of how to
make use of it.

=head1 Functions

=over

=item new

Returns a new SWISS::BaseClass object.

=item rebless

Converts a base class into your class!  Call as $self->rebless($class) where
$self is a base class object.  It returns $self, reblessed, with the correct
member variables.

=item initialize

Override this in each derived class to provide class specific initialization.
For example, initialize may put arrays into member variables that need them.
You must provide an initialize function.

=item reformat

Some line objects are implementing "lazy writing". This means that on writing an entry, they are only reformatted if they have been modified. The method reformat forces an object to be reformatted even if its content has not been modified. This may be useful e.g. to make sure the current formatting rules are applied.

=item setEvidenceTags @array

Sets the evidence tags of the object to the list passed in @array. 

=item addEvidenceTag string

Adds the evidence tag to the object.

=item deleteEvidenceTag string

Deletes the evidence tag from the object. 

=item hasEvidenceTag string

returns true if the object has the evidence tag.

=item getEvidenceTags

returns the array of evidence tags of the object

=item Check4Clashes

This function checks your classes member variable list for clashes with any class
that it inherits from (any class that can(_containsFields) returns true on!).  If it
detects that in any base class that any data members have been already defined,
it dies with a listing of the variables already used.

It stops searching a root of an inheritance hierachy when it can find no baseclasses that
support _containsFields.  It will find all clashes in an entire inheritance tree.

So in the inheritance hierachy of

 SWISS::BaseClass -> A -> B -\
                             > E
 SWISS::BaseClass -> C -> D -/

where E is the most derived class, if E contains names that clash with A members
and names that clash with B members, both the A and B member clashes will be reported.

If there were clashes with B and C, say, then again, all of the clashes would be reported.

=item _containsFields

This function is responsible for comparing a classes fields with the set in the
calling package.  This implimentation will work for cases where all of the
classes that contribute fields are derived from SWISS::BaseClass.  You may wish to
make your own class fit this interface, so what follows is an interface API.

_containsFields assumes that the first argument is the package that it is being called in.
The following arguments are taken to be a list of fields which to check are not found
in members of the current package.

It should return either C<undef> or a reference to an array of name clashes in the format
C<package::variable>.  It should call it's self for each parental class that supports this
function.

So it would look something like
  _containsFields {
    my $class = shift;
    my @toCheck = @_;

    foreach @toCheck {
      check that they are not in me.  If they are, add them to the list of clashes to return.
    }

    add all base class clashes to your list of clashes

    if there were name clashes return a reference to them

    otherwise return undef
  }

=item equal

If two objects are equal, it returns true.

Warning: This funktion compares two objects using a simple dump in Perl format, see Data::Dumper module. The comparison also takes private variables into account. Therefore: If the method 'equal' returns true, the objects are guaranteed to be equal, but it might return false although the two objects are equal in they public attributes.

=item copy

Returns a "deep copy" of the object.

=back

=head1 A skeletal derived class

 package myDerived;

 use vars qw ( @ISA %fields );

 BEGIN {
    @ISA = ('SWISS::BaseClass');

    %fields = (
	       'i' => 1,
	       'hash' => undef
	       );

    myDerived->check4Clashes();
 }

 sub new {
    print "myDerived::new(@_)\n";
    my $class = shift;
    my $self = new SWISS::BaseClass;
    
    $self->rebless ($class);
    
    return $self;
 }

 sub initialize {
    my $self = shift;
    $self->{'hash'} = {};
 }

A class derived from myDerived would just substitute the name myDerived
for SWISS::BaseClass.  Hey presto - all sorted!
