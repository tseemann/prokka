package SWISS::ACs;

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
  my @tmp;

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'AC'})/m){    
    foreach $line (split /\n/m, $1) {
      # drop **   Comment lines 
      if (($line =~ /^\*\*/) 
	  &&
	  ($line !~ /^\*\*   [OPQ][\w]{5};/)) {
	if ($main::opt_warn) {
	  carp "Dropped \'$line\' from AC line block";
	}
	next;
      }
      $self->{indentation} += $line =~ s/^ //;
      $line = SWISS::TextFunc->cleanLine($line);  
      @tmp = SWISS::TextFunc->listFromText($line, ';\s*', ';\s*');
      push (@{$self->list()}, @tmp); 
    }
  }

  $self->{_dirty} = 0;
  
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my (@lines, $newText);

  $newText = join('; ', @{$self->list}) . ";";
  my $prefix = "AC   ";
  my $col = $SWISS::TextFunc::lineLength;
  $col++, $prefix=" $prefix" if $self->{indentation};
  $newText = SWISS::TextFunc->wrapOn($prefix, $prefix, $col, $newText, '; ');

  $self->{_dirty} = 0;

  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'AC'});
}

# sort secondary ACs
sub sort {
  my $self = shift;
  my $l = $self->{list};
  if (@$l > 1) {
    @$l = ($l->[0], sort @$l[1..$#$l]);
  }
  return 1;
}

sub update {
  my $self = shift;
  my $force = shift;

  # Potential duplicates should be removed.
  $self->unique();
  # The secondary ACs should be sorted.
  $self->sort();

  return 1;
}


1;				# says use was ok

__END__

=head1 Name

SWISS::ACs

=head1 Description

B<SWISS::ACs> represents the AC (accession) lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

The SWISS-PROT format has recently been changed to multiple AC lines.
This module will read

 Ordinary AC lines
    AC   P10585;

 The old temporary format (for internal use only)
    AC   Q57333; O08291; O08202; O08292; O08203; O08293; O08204; O08294;
    **   O08205; O08295; O08206; O08296; O08207; O08297; O08208; O08298;
    **   O08213;

 and the new format.
    AC   Q57333; O08291; O08202; O08292; O08203; O08293; O08204; O08294;
    AC   O08205; O08295; O08206; O08296; O08207; O08297; O08208; O08298;
    AC   O08213;

But, SWISS::ACs will DROP funny ** comment lines that are sometimes
found following an AC line:

    AC   Q48558; P71434;
    **   MERGED 2 TREMBL ENTRIES.

This module will always write the new format with multiple AC lines.

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

This is an array containing a list of all the accession numbers associated
with this entry.  The first member will be the primary accession number, and
any following are the secondary accession numbers.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=item sort

This method sorts the secondary AC numbers alphanumerically, i.e.
all but the first. The primary AC number must never be sorted.

=back
