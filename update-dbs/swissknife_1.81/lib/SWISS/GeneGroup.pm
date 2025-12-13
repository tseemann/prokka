package SWISS::GeneGroup;

use vars qw($AUTOLOAD @ISA @EXPORT_OK @GN_LISTS %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::GN;

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');

  @GN_LISTS = qw(Names OLN ORFNames);
  
  %fields = (
    'Names' => undef,
    'OLN' => undef,
    'ORFNames' => undef,
    'is_old_format' => undef,
	    );
}

sub new {
  my $ref = CORE::shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::ListBase;
  
  $self->rebless($class);
  return $self;
}

sub initialize {
  my $self = CORE::shift;
  for my $listname (@GN_LISTS) {
    $self->{$listname} = new SWISS::ListBase;
  }
  $self->{is_old_format} = 0;
}

sub fromText {
  my $class = CORE::shift;
  my $text = CORE::shift;

  unless ($text =~ /^ *(?:Name|Synonyms|OrderedLocusNames|ORFNames)=/) {
    return _fromText_old($class, $text, @_);
  }

  my $self = new($class);
  $self->initialize;
  $text =~ s/[;\s]+$//;
  if ($text =~ s/(^|; +)ORFNames=(.*?)(?=; |;\Z|\Z)//) {
    $self->ORFNames->set(map {SWISS::GN->fromText($_)} split ', +(?!ECO:\d)', $2);
  }
  if ($text =~ s/(^|; +)OrderedLocusNames=(.*?)(?=; |;\Z|\Z)//) {
    $self->OLN->set(map {SWISS::GN->fromText($_)} split ', +(?!ECO:\d)', $2);
  }
  my @names;
  if ($text =~ s/(^|; +)Synonyms=(.*?)(?=; |;\Z|\Z)//) {
    push @names, split ', +(?!ECO:\d)', $2;
  }
  if ($text =~ s/(^|; +)Name=(.*?)(?=; |;\Z|\Z)//) {
    unshift @names, split ', +(?!ECO:\d)', $2; #ensure space because valid names may contain a comma
  }
  if (length $text) {
    if ($main::opt_warn) {
      carp "GN parse error, left text $text";
    }
    push @names, $text;
  }
  $self->Names->set(map {SWISS::GN->fromText($_)} @names);
  return $self;
}


sub _fromText_old {
  my $self = new(CORE::shift);
  my $text = CORE::shift;

  if( $text =~ /^\(/ && $text =~ /\)$/ ){
    $text =~ s/^\(//; 
    $text =~ s/\)$//;
  }
  $self->Names->set(map{SWISS::GN->fromText($_)}split / OR /i, $text); 
  $self->is_old_format(1);
  return $self;
}

sub toText {
  my $self = CORE::shift;
  if ($self->is_old_format) {
    return _toText_old($self, @_);
  }
  my @newText;
  if ($self->Names->size)  {
	  push @newText, "Name=" . $self->Names->head->toText . ";";
	  if ($self->Names->size > 1) {
		  push @newText, "Synonyms=" . join(", ", map {$_->toText} $self->Names->tail) . ";";
	  }
  }
  if ($self->OLN->size)  {
    push @newText, "OrderedLocusNames=" . join(", ", map {$_->toText} $self->OLN->elements) . ";";
  }
  if ($self->ORFNames->size)  {
    push @newText, "ORFNames=" . join(", ", map {$_->toText} $self->ORFNames->elements) . ";";
  }
  return join " ", @newText;
}

sub _toText_old {
  my $self = CORE::shift;
  my $delimiter = CORE::shift || ' OR ';
  my $a=join $delimiter, map{$_->toText} @{$self->list}; #FIXME
  return $a;
}

sub sort {
	my $self = CORE::shift;
	my @name1 = $self->Names->splice(0, 1);
  $self->ORFNames->set( sort { lc($a->text) cmp lc($b->text) || $a->text cmp $b->text } $self->ORFNames->elements );
	return $self->Names->set(@name1, sort {lc($a->text) cmp lc($b->text) || $a->text cmp $b->text} $self->Names->elements);
}

# access Name and Synonyms
sub Name {
	my $self = CORE::shift;
	if (@_) {
		my $newName = CORE::shift;
		return $self->Names->splice(0, 1, $newName);
	}
	else {
		return $self->Names->head;
	}
}

sub Synonyms {
	my $self = CORE::shift;
	if (@_) {
		if ($self->Names->size > 1) {
			return $self->Names->splice(1, $self->Names->size-1, @_);
		}
		else {
			return $self->Names->set(@_);
		}
	}
	else {
		return $self->Names->tail;
	}
}

# ListBase emulation
sub list {
	my $self = CORE::shift;
	return [$self->elements];
}

sub get {
	my $self = CORE::shift;
	my $pattern = CORE::shift;
	return grep {$_->text =~ /^$pattern$/} $self->elements;
}

sub head {
	my $self = CORE::shift;
	return $self->list->[0];
}

sub tail {
	my $self = CORE::shift;
	my @el = $self->elements;
	CORE::shift @el if @el>0;
	return @el;
}

sub size {
	my $self = CORE::shift;
	return $self->Names->size + $self->OLN->size + $self->ORFNames->size;
}

sub isEmpty {
	my $self = CORE::shift;
	return not $self->size;
}

sub elements {
	my $self = CORE::shift;
	return
		$self->Names->elements,
		$self->OLN->elements,
		$self->ORFNames->elements;
}

sub item {
	my $self = CORE::shift;
	my $n = CORE::shift;
	return $self->list->[$n];
}

sub push {
	my $self = CORE::shift;
	$self->Names->push(@_);
}

sub pop {
	my $self = CORE::shift;
	for my $listname (@GN_LISTS) {
		next unless $self->{$listname}->size;
		return $self->{$listname}->pop(@_);
	}
	return undef;
}

sub shift {
	my $self = CORE::shift;
	for my $listname (@GN_LISTS) {
		next unless $self->{$listname}->size;
		return $self->{$listname}->shift(@_);
	}
	return undef;
}

sub splice {
	my $self = CORE::shift;
	for my $listname (@GN_LISTS) {
		next unless $self->{$listname}->size;
		return $self->{$listname}->splice(@_);
	}
	return undef;
}

sub unshift {
	my $self = CORE::shift;
	$self->Names->unshift(@_);
}

sub set {
	my $self = CORE::shift;
	$self->initialize;
	$self->Names->set(@_);
}

sub add {
	my $self = CORE::shift;
	$self->Names->add(@_);
}

sub filter {
  my $self = CORE::shift;

  my $new = new ref($self);
  for my $listname (@GN_LISTS) {
    $new->{$listname} = $self->{$listname}->filter(@_);
  };

  $new->{indentation} = $self->{indentation};

  return $new;
}


1;

__END__

=head1 Name

SWISS::GeneGroup.pm

=head1 Description

A B<SWISS::GeneGroup> object contain all synonyms for a given
gene name. See B<SWISS::GNs> for a description of the gene name
format.

=head1 Inherits from

SWISS::BaseClass.pm

(also implements many methods from SWISS::ListBase.pm)

=head1 Attributes

=over

=item C<Names>

  Each list element is a SWISS::GN object, describing a primary name
  or synonym. Concatenation of Name and Synonyms lists.

=item C<OLN>

  Each list element is a SWISS::GN object, describing an
  OrderedLocusName.

=item C<ORFNames>

  Each list element is a SWISS::GN object, describing an ORFName.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head2 Specific methods

=over

=item Name

Returns the Name (primary name).

=item Synonyms

Returns the Synonyms.

=item elements

  Concatenates all elements from Names, OLN and ORFNames in
  a single array.

=back

=head2 List manipulation methods

Since GeneGroup was a previous implementation of SWISS::ListBase,
the list manipulation methods below are provided to facilitate
compatibility.

=over

=item size

=item isEmpty

=item elements

=item filter

=item get I<(deprecated)>

=item head I<(deprecated)>

=item tail I<(deprecated)>

=item item I<(deprecated)>

=item push I<(deprecated)>

=item pop I<(deprecated)>

=item shift I<(deprecated)>

=item splice I<(deprecated)>

=item unshift I<(deprecated)>

=item set I<(deprecated)>

=item add I<(deprecated)>

=back
