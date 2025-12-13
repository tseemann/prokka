package SWISS::Stars;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields $defaultClass %month2number 
            $header $footer $mheader $mfooter $headerPattern $footerPattern); 

use Exporter;
use Carp;
use strict;

use SWISS::Stars::default;
use SWISS::Stars::DR;
use SWISS::Stars::aa;
use SWISS::Stars::EV;

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass');
  
  %fields = (
	    );

  # The default class which handles new tags in the PRELIMINARY SECTION
  $defaultClass = "SWISS::Stars::default";

  $header = "**   #################     SOURCE SECTION     ##################\n";
  $footer = "**   #################    INTERNAL SECTION    ##################\n";

  $mheader = quotemeta $header;
  $mfooter = quotemeta $footer;
  $headerPattern = '\*\*   \#+\s+SOURCE SECTION\s+\#+\n';
  $footerPattern = '\*\*   \#+\s+INTERNAL SECTION\s+\#+\n';


  %month2number =  
    ('01'=>'JAN', '02'=>'FEB', '03'=>'MAR', '04'=>'APR', 
     '05'=>'MAY', '06'=>'JUN', '07'=>'JUL', '08'=>'AUG', 
     '09'=>'SEP', '10'=>'OCT', '11'=>'NOV', '12'=>'DEC');
}


sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::BaseClass;
  
  $self->rebless($class);
  return $self;
}

sub initialize {
}

sub AUTOLOAD {
  my $self = shift;
  my $value;
  my $name = $AUTOLOAD;
  my $fullname = $name;
  
  # * Initialise
  if (@_) {
    $value = shift;
  }
  else {
    undef $value;
  }

  # get only the bit we want
  $name =~ /::DESTROY/ && return;
  $name =~ s/.*://;		

  # If a value is passed, try to set it
  # No type verification - use at your own risk!!!
  if (defined $value) {
    if ((exists $self->{$name})
       ||
	# is it a permitted object?
       (length ($name) == 2 && ref $value )) {

      $self->{_dirty} = 1;
      # if a subobject is set, it's dirty
      if (defined $self->{$name}->{_dirty}) {
	      $self->{$name}->{_dirty} = 1;
      };
      return $self->{$name} = $value;
    }
    else {
      confess "Can't set $name to $value. Probably passed a wrong variable name into " . ref($self);
    }
  }
  else {
    # * An object has been requested
    # If the object exists, return it
    if (defined $self->{$name}) {
      return $self->{$name};
    }
    else {
      # no object $name yet, create and return it
      if (defined &{$fullname . "::fromText"}) { # use specific subclass  
	     return $self->{$name} = $fullname->fromText($self->{_textRef});
      }
      else {
      	# check if name is a valid object tag
      	if (length $name == 2) { # use generic Stars::default
      	  $self->{$name} = $defaultClass->fromText($self->{_textRef}, $name);
      	  return $self->{$name};	  
      	}
      	else {
      	  confess "Can't create $name. Probably passed a wrong variable name into " . ref($self);
      	};
      }
    }     
  }
}

sub fromText {
  my $self = new(shift);
  my $textRef = shift;
  my $lines = '';

  if ($$textRef =~ /$SWISS::TextFunc::linePattern{'St'}/m){ 
    $lines = $&;

    # remove header and footer lines
    $lines =~ s/($headerPattern)|($footerPattern)//mg;
  
    # Cleanup empty lines at the beginning of the block
    $lines =~ s/\A\*\*\s*\*{0,2}\n//gm;
  };

  $self->{'_textRef'} = \$lines;
  return $self;
};

sub toText {
  my $self = shift;
  my $textRef = shift;
  my $subObject;

  # reparse (maybe this is called from entry reformat) if is set to 'dirty'
  $self->update( 1 ) if $self->{ _dirty };

  # call toText for the subobjects
  foreach $subObject ( grep {length $_ == 2} sort keys %$self ) { # p.s. only toText already parsed/modified subObjects (not all!)
    if ($self->{$subObject}->{_dirty}) { # p.s. only call subobject toText if is dirty (modified or forced reparse/build asked)
      $self->{$subObject}->toText($self->{_textRef}, $subObject); # modifies _texRef content (that contains all **!) for the specified line type=subObject
      $self->{_dirty} = 1;
    }
  }

  if ($self->{_dirty}) {
    # add SOURCE SECTION header (unless it's already there) if there are any source **   lines
     unless ( ${$self->{_textRef}} =~ /$headerPattern/ ) {
        if ( $self->aa->size && grep { !/^PROSITE; PS/ } $self->aa->elements ) { # p.s. exclude **  PROSITE: are not source!
          ${$self->{_textRef}} =  $header . ${$self->{_textRef}};
        }   
        # Add empty line at the beginning, unless it's already there
        unless (${$self->{_textRef}} =~ /^\*\*\n/) {
          ${$self->{_textRef}} =  "\*\*\n" . ${$self->{_textRef}};
        }
    }

    # add INTERNAL SECTION header, unless it's already there
    unless ( ${$self->{_textRef}} =~ /$footerPattern/) {
      if (${$self->{_textRef}} =~ /\n\*\*\S{2} .*/) { # no header yet, add it before first **XX (non source) line
        ${$self->{_textRef}} = $` . "\n" . $footer . substr($&, 1) . $';
      } else {
        ${$self->{_textRef}} .= $footer;
      };
    }

    SWISS::TextFunc->insertLineGroup($textRef, ${$self->{_textRef}}, 
				     $SWISS::TextFunc::linePattern{'St'});
    $self->{_dirty} = 0;
    return 1;
  }   
  else {
    return 1;
  };
};
  
# Stars is a master object like entry. Therefore it has to update itself 
# and its subobjects. The text representation has also to be updated.
sub update {
  my $self = shift;
  my $force = shift;
  my $subObject;
  my @subObjects;

  
  if ($force) { # Make sure all subobjects are parsed if $force is set.
    @subObjects = ${$self->{'_textRef'}} =~ /\*\*(\w\w) .*/g; # p.s. "**  " (source section **) not touched!  
    @subObjects = SWISS::TextFunc->uniqueList(@subObjects);
  } else {
    @subObjects = grep {length $_ == 2} keys %$self;
  }

  # mark targeted (were accessed/modified or all if $force) subObjects as dirty, will lead to their re-parsing/building in toText
  foreach $subObject (@subObjects) {
    $self->$subObject()->{_dirty} = 1;
    $self->$subObject()->update();# p.s. update method is not re-implemented in Stars sub classes = is from ListBase: calls sort!
  }

  $self->{_dirty} = 1;

  return 1;
}

sub insertLineGroup {
  # update/insert back text (preserving original order) for specific **key (subObject) into object _textRef (containing all **)
  my ($class, $textRef, $text, $tag) =  @_;
  my $seen = 0;
  # replace (1st) old targeted block with fresh data (grouped $tag lines into $text), subsequent targeted blocks (malformed: ** should be grouped in continuous  blocks) should be removed
  $$textRef =~ s/^(\*\*$tag .*\n){1,}/{my $rep = $seen ? "": $text; $seen =1; $rep}/egm or $$textRef .= $text;
  return 1;
};

#   Function: transfer from the old into the new ** section format
#   Args    : $curatedBlock : if set, the function supposes that 
#                             the curator's comments are in a block 
#                             started by $curatedStart and 
#                             terminated by $curatedStop
#   Returns : true
sub translate {
  my $self = shift;
  my $curatedBlock = shift;
  my ($tmp, $tmpText, @tmp);

  # transfer
  # **   XXXX_ARATH
  if (@tmp = $self->aa->get('[A-Z0-9]{1,4}\_[A-Z0-9]{3,5}')){
    $self->aa->del('[A-Z0-9]{1,4}\_[A-Z0-9]{3,5}');

    # Remove duplicates
    if ($#tmp > 0) {
      $tmp = new SWISS::ListBase;
      $tmp->add(@tmp);
      $tmp->unique();
      @tmp = $tmp->elements();
    }

    $self->ID->add(@tmp);
  };

  # Delete PFAM predictions, they will be redone.
  $self->aa->del('.*PREDICTED BY PFAM.*');
  
  # Delete DR PRINTS, they are now in the main section
  $self->aa->del('DR   PRINTS.*');

  # Delete DR PROSITE
  $self->aa->del('PROSITE.*');

  # Delete ** PSnnnnn lines
  $self->aa->del('PS\d{5}.*');

  # Delete ** EMOTIF
  $self->aa->del('EMOTIF.*');
  
  # Delete ** MISSING lines
  $self->aa->del('MISSING.*');

  # Delete 
  # **   -!- SUBCELLULAR LOCATION: NUCLEAR (POTENTIAL;
  # **       PREDICTED BY NNPSL; 57.9 ACCURACY).
  $self->aa->del('.*SUBCELLULAR LOCATION:.*POTENTIAL.*');
  $self->aa->del('.*PREDICTED BY NNPSL.*');

  # transfer
  # **   DR   GENBANK JOURNAL-SCAN; G1754741.
  if (@tmp = $self->aa->get('DR   GENBANK JOURNAL-SCAN.*')){
    $self->aa->del('DR   GENBANK JOURNAL-SCAN.*');
    $self->GP->add(@tmp);
  };

  # transfer
  # **   TAX_ID; 4932; Saccharomyces cerevisiae.
  my ($line) = $self->aa->get('TAX_ID; .*');
  if ($line) {
    $line =~ /^TAX_ID; (-*\d+);/;
    $self->OX->add($1 . ";");
    $self->aa->del('TAX_ID.*');
  }

  # transfer 
  # **   RULE RU000204.
  # **   RULE       RU000195; 1998-01-22.
  # to
  # **RU RU000201; 22-SEP-1999.
  my ($rule, $rulenum, $year, $month, $day);
  if (@tmp = $self->aa->get('RULE\s+RU\d{6}.*')){
    foreach $rule (@tmp) {
      ($rulenum) = $rule =~ /RULE\s+(RU\d{6})/;
      ($year, $month, $day) = $rule =~ /(\d{4})-(\d{2})-(\d{2})/;
      if ($year){
	$month = $month2number{$month};
	$self->RU->add("$rulenum; $day-$month-$year.");
      } else {
	$self->RU->add("$rulenum;");
      }      
    };
    $self->aa->del('RULE\s+RU\d{6}.*');
  }

  # transfer the curator's comments
  my $curatedStart = '((CREATED AND FINISHED BY)|(ANNOT )).*';
  my $curatedText = '((FINISHED BY )|(ANNOTATED BY )|(UPDATED BY )|(ANNOT BY )).*';
  my $curatedStop = 'CURATED\.?';

  if ($curatedBlock) {
    # Parse a prestructured block of curator's comments
    my $inBlock = 0;
    foreach $line ($self->aa->elements) {
      if ($line =~ /\A$curatedStart\Z/i) {
	$inBlock = 1;
      };
      if ($inBlock) {
	$self->aa->del(quotemeta $line);
	$self->ZZ->add($line);
	if ($line =~ /\A$curatedStop\Z/) {
	  $inBlock = 0;
	};
      }
    }
  } else {
    # Transfer only well-defined lines of curator's comments
    foreach $line ($self->aa->elements) {
      if ($line =~/\A$curatedStart\Z/i
	  ||
	  $line =~/\A$curatedText\Z/i
	  ||
	  $line =~/\A$curatedStop\Z/
	 ) {
	$self->aa->del(quotemeta $line);
#$self->ZZ->add($line);
      }
    }
  }

  $self->{_dirty} = 1;

  return 1;
}
  
sub sort {
  my $self = shift;
    
    # sort **subblocks (toText sort parsed **subblocks, just force parsing)
    $self->update(1);
    
    # sort within each **subblock
    my $subObject;
    # Recursively call sort for the subobjects (already accessed)
    foreach $subObject (grep {length $_ == 2} keys %$self) {
        $self->{$subObject}->sort;
    };
    return 1;
}

sub cleanUpReferences {
  my $self = shift;
  my @lines = @{$self->list()};

  my ($start,$end,$dirty);

 REFERENCE:
  for ($start=0; $start <= $#lines; $start++){
    # find a reference start
    while ($start<=$#lines && $lines[$start] !~ /^\[\d+\]/){
      $start++;
    }
    last if $start>$#lines;
    
    $end=$start+1;
    while ($end<=$#lines && $lines[$end] !~ /^\[\d+\]/){$end++;}
    last if $end>$#lines;
    
    # now look for similar references
    my $length = $end - $start - 1;
    my $next;
  TRY:
    for ($next=$end; $next<=$#lines; $next++){
      next if $lines[$next] !~ /^\[(\d+)\]/;
      
      my $j;
      for ($j=1; $j<=$length; $j++){
	next REFERENCE if $j>$#lines;

	#printf "%03d<<<%-20.20s>>%-20.20s%03d\n"
	#  ,$start+$j,$lines[$start+$j],
	#  $lines[$next+$j],$next+$j;
	next TRY
	  if ($lines[$start+$j] ne $lines[$next+$j]);
	
      }
      
      my @removed = splice(@lines, $next, $j); 
      $main::opt_debug > 2 && print "Stars::cleanUpReferences: Removed\n".
	join("\n",@removed)."\n";
      $dirty |= 1;
      $next--;
    }

    $start++
  }

  if ($dirty){
    @{$self->{'list'}} = @lines;
    $self->_dirty(1);
  }
  return $dirty;
  
}


1;

__END__  

=head1 NAME 

B<SWISS::Stars.pm>

=head1 DESCRIPTION

B<SWISS::Stars> represents the ** lines within an SWISS-PROT + TrEMBL
entry. These are the lines with the line tag ** which are normally not 
publicly visible.

B<SWISS::Stars> is a master object like SWISS::Entry. It contains subobjects which represent the different line types in the ** section. Each line type has a two letter tag in addition to the ** line tag. This module has been written to allow easy addition of new ** line types. To use a new ** line tag, just use the tag as an object dereference. Example:

 $entry->Stars->XX->add("New XX tag line.","Second new XX tag line.");

If there is no class SWISS::Stars::XX, the class of the new object will be SWISS::Stars::default, which handles lines with the corresponding tag as an array of lines. If more specific handling is required, a new class SWISS::Stars::XX can be created following the template of SWISS::Stars::default. An example is SWISS::Stars::aa.

Subclass names and new line tags have to be two-letter-tags. B<No checks are made wheter the dereferenced tag is allowed.>

Access to the (old) unstructured ANNOTATOR'S SECTION is provided by the line tag 'aa'. 

 $entry->Stars->aa->add("Testline 1.","Second new test line.");

will add these two lines to the ANNOTATOR'S SECTION.

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

No public attributes apart from the subclasses.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=item update

=back
