package SWISS::IDs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;

# Example of an ID line:
# ID   FUCK_ECOLI     STANDARD;      PRT;   482 AA.
# ID   primaryID      dataClass;     moleculeType; length AA.
#[** Further IDs] 
#
# New format, starting with release 9.0:
# ID   CYC_PIG                 Reviewed;         104 AA.
# ID   Q3ASY8_CHLCH            Unreviewed;     36805 AA.
# ID   %-24s%-11s%10d AA.

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');
  
  %fields = (
	     'dataClass' => undef,
	     'moleculeType' => undef,
	     'stars' => undef, # should second ID line be ** line or not?
       'length' => undef # Number of amino acids.
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
  my $self = shift;
  $self->{'dataClass'} = 'PRELIMINARY';
  $self->{'moleculeType'} = 'PRT';    
  $self->{'length'} = 0;     
  $self->{'stars'} = 0;    
}

sub fromText {
  my $self = new(shift);

  my $textRef = shift;
  my ($line, @lines);
  my @tmp;

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'ID'})/m){
    @lines = (split /\n/m, $1);
    # process main ID line
    $line = shift @lines;
    $self->{indentation} += $line =~ s/^ //;
    $line = SWISS::TextFunc->cleanLine($line);
    @tmp = SWISS::TextFunc->listFromText($line, ';*\s+', '\.');
    push (@{$self->list()}, shift @tmp);
    
    # assign the rest of the first ID line
    $self->{'dataClass'} = shift @tmp;
    if (@tmp > 2) {
			$self->{'moleculeType'} = shift @tmp;
    }
    $self->{'length'} = shift @tmp;
    
    foreach $line (@lines) {
      
      if ($line =~/\*\*/) {
        $self->{stars} = 1;
      }
      
      $self->{indentation} += $line =~ s/^ //;
      $line = SWISS::TextFunc->cleanLine($line);
      @tmp = SWISS::TextFunc->listFromText($line, ';\s+', ';\s*');
      push (@{$self->list()}, @tmp); 
    }
  }
  else {
    ($main::opt_warn > 1) && carp "No ID line in $$textRef";
  }

  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my (@tmp, $line, $newText);
	
  # print ID line
	if ($self->{dataClass} =~ /reviewed/i) {
		$newText = sprintf("ID   %-24s%-11s%10d AA.\n",
					 $self->head, $self->{dataClass} . ';', $self->{'length'});
	} else {
		$newText = sprintf("ID   %-11s %11s; %8s; %5d AA.\n",
					 $self->head, $self->{dataClass}, $self->{moleculeType}, 
					 $self->{'length'});
	}
  
  # print secondary IDs in ** line, or in ID line for STANDARD entries
  if ($#{$self->list} > 0) {
    @tmp = @{$self->list};
    shift @tmp;
    my $indent = $self->{indentation} ? " " : "";
    if (($self->{stars} == 0) && ($self->{dataClass} eq "STANDARD")) {
        $line = join "", map {"${indent}ID   $_\n"} @tmp;
    }
    else {
        $line = join('; ', @tmp) . ";";
        $line = SWISS::TextFunc->wrapOn("\*\*   ", "\*\*   ", $SWISS::TextFunc::lineLength, $line, '; ');
    }
    $newText .= $line;
  };
  
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'ID'});
}

# IDs must never be sorted, overwrite the inherited sort method.
sub sort {
  return 1;
}



1;

__END__

=head1 Name

SWISS::IDs.pm

=head1 Description

B<SWISS::IDs> represents the ID lines of a SWISS-PROT + TREMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

This is an array containing a list of all the IDs associated
with this entry.  The first member will be the primary ID, and
any following are the secondary IDs which are not shown in the public section of the entry.

=item dataClass

The data class, either STANDARD or PRELIMINARY for data from releases 
prior to 9.0, or Reviewed or Unreviewed for data from later releases.

=item moleculeType 

The molecule type, currently only PRT.

=item length

The protein length in amino acids.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=item sort

IDs must never be sorted, so this method does nothing (but
it overwrites the inherited method). 
