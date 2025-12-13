package SWISS::OSs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::OS;

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

sub initialize {
}

sub fromText {
  my $self = new(shift);
  
  my $textRef = shift;
  my $line;
 
  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'OS'})/m){ 
    $line = $1;
    $self->{indentation} = $line =~ s/^ //mg;
    $line = SWISS::TextFunc->joinWith('', ' ', '(?<! )-', 'and ',
                                      map {SWISS::TextFunc->cleanLine($_)}
                                          (split "\n", $line));
                                          
    $line =~ s/\.\r?\n?$//;
    push (@{$self->list()}, SWISS::OS->fromText( $line ) );
        # n.b. identical entries from distinct species are not merged anymore
        # one entry has only one species! but keep OSs as a list of OS elems
        # to keep compatibility with old code!

    #@tmp = SWISS::TextFunc->listFromText($line, ',\s+(?i:and\s+)?(?![^\(]+\))', '\.');
    #@tmp = map {SWISS::OS->fromText($_)} @tmp;
    #push (@{$self->list()}, @tmp); 
    
    
  }
  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;
  my @tmp;
  my $newText = '';

  if ($self->size > 0) {
    @tmp = map {$_->toText} $self->elements();

    # Add commas as separators
    map {$_ .= ','} @tmp;

    # delete last comma
    $tmp[$#tmp] =~ s/\,$//;

    # drop trailing spaces and dots
    # (Rattus SP.)
    $tmp[$#tmp] =~ s/[\. ]+(($SWISS::TextFunc::evidencePattern)*$)/$1/m;
    
    # add final dot
    $tmp[$#tmp] .= '.';

    # insert an 'and' after the last but one species
    if ($#tmp > 0) {
      $tmp[$#tmp-1] .= ' and';
    }
    
    # wrap lines where one OS extends beyond one line
	for (my $i=0; $i<@tmp; $i++) {
		my $prefix = "OS   ";
		my $col = $SWISS::TextFunc::lineLength;
		$col++, $prefix=" $prefix" if $self->{indentation};
		$tmp[$i] = SWISS::TextFunc->wrapOn($prefix, $prefix, $col,
					$tmp[$i], 
					'\s+');
	}
    
    # connect all OS lines
    $newText = join('', @tmp);
    
  };
  $self->{_dirty} = 0;
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'OS'});
}

# OSs must never be sorted, overwrite the inherited sort method.
sub sort {
  return 1;
}

# convert scientific name to the abbreviated form as it is used
# in the RC SPECIES line
# input   $scientific:  Full scientific name (e.g. 'Escherichia coli')
#         $superregnum: 'V' for viruses, 'E' for eukaryotes etc.
#                       (By now, only 'V' or not 'V' is important
# returns abbreviated name (e.g. 'E.coli')
sub scientific2rc {
  my $scientific  = shift;
  my $superregnum = shift;

  unless ($scientific) {
    croak "No input";
    return undef;
  }
  my $rc = $scientific;
  my %common=
    ('RATTUS NORVEGICUS'     => 'Rat',
     'HOMO SAPIENS'          => 'Human',
     'MUS MUSCULUS'          => 'Mouse',
     'BOS TAURUS'            => 'Bovine',
     'GALLUS GALLUS'         => 'Chicken',
     'SUS SCROFA'            => 'Pig',
     'ORYCTOLAGUS CUNICULUS' => 'Rabbit',
     'OVIS ARIES'            => 'Sheep',
     'ZEA MAYS'              => 'Maize',
     'EQUUS CABALLUS'        => 'Horse',
     'GLYCINE MAX'           => 'Soybean',
    );

  
  if ($superregnum eq 'V') {
    $rc =~ s/\bBACTERIO(PHAGE)/$1/i;
    return $rc;
  } else {
    my $common = $common{uc($scientific)};
    return $common if $common;

    return $scientific if $scientific =~ /^\w+ SP\.$/i;
    my $done = 0;
    
    die "no input" unless $rc;
    $done ||= ($rc =~ s/^(\w)\w+ ([A-Z\-]+)$/$1.$2/i);
    $done ||= ($rc =~ s/^(\w)\w+ (\w)[A-Z\-]+ ([A-Z\-]+)$/$1.$2.$3/i);
    $done ||= ($rc =~ s/^(\w)\w+ \(STRAIN (.*)\)$/$1.$2/i);
    $done ||= ($rc =~ s/^(\w)\w+ SP\. \(STRAIN (.*)\)$/$1.$2/i);
    $done ||= ($rc =~ s/^(\w)\w+ SP\.$/$1.$2/i);
    $done ||= ($rc =~ s/^(\w)\w+ X ([A-Z\-]+)$/$1.$2/i);
   if (!$done){ 
     my $infix;
      foreach $infix ('SUBSP\.','STRAIN','VAR\.','PV\.','BIOVAR',
		     'BV\.','F\. SP\.' ){
	$done ||= ($rc =~ s/^(\w)\w+ (\w)[A-Z\-]+ $infix (.*)$/$1.$2.$3/i);
	$done ||= ($rc =~ s/^(\w)\w+ (\w)[A-Z\-]+ \($infix (.*)\)$/$1.$2.$3/i);
	last if $done;
      }
    }
    return $done ? $rc : '';
  }
}

1;

__END__

=head1 Name

SWISS::OSs

=head1 Description

B<SWISS::OSs> represents the OS lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
 http://www.expasy.org/sprot/userman.html . The OSs object is a container object which holds a list of SWISS::OS objects.

n.b. entries from distinct species are not merged anymore, OSs will therefore
only contain one OS (OS is still divided into a list of OS elements to keep 
compatibility with old code)!

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

  Each list element is a SWISS::OS object.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back
