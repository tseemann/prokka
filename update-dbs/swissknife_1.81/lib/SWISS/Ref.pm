package SWISS::Ref;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields @RCtopics @RXtopics
	    %linePattern @linePattern
	    $print_titles $uppercase);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::BaseClass;
use SWISS::RCelement;

$print_titles = 1;
$uppercase = 0;

BEGIN {
  @EXPORT_OK = qw($print_titles $uppercase);
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass');
  
  @linePattern = ('^(RN   .*\n){1}',
		  '^(RP   .*\n)+',
		  '^(RC   .*\n)+',
		  '^(RX   .*\n)+',
		  '^(\*\*   \S+=None\b.*\n)+',
		  '^(RG   .*\n)+',
		  '^(RA   .*\n)+',
		  '^((RT   .*\n)|(\*\*   .*NO TITLE.*\n))+',
		  '^(RL   .*\n)+');

  my ($line, $lineId);
  foreach $line (@linePattern) {
    ($lineId) = $line =~ /\(+(.\S)/;
    $linePattern{$lineId} = $line;
  }


  %fields = ('RN' => undef,
	     'RP' => undef,
	     'RC' => undef,
	     'RX' => undef,
	     'RG' => undef,
	     'RA' => undef,
	     'RT' => undef,
	     'RT_comment' => undef,
	     'RX_comment' => undef,
	     'RL' => undef,
	     'journal' => undef,
	     'issn' => undef,
	     'volume' => undef,
	     'pages' => undef,
	     'year' => undef,
	     'etal' => undef,
	    );

  @RCtopics = ('SPECIES', 'STRAIN', 'PLASMID', 'TRANSPOSON', 'TISSUE');

  @RXtopics = qw(MEDLINE PubMed AGRICOLA DOI);
}

sub new {
  my $ref   = shift;
  my $class = ref($ref) || $ref;
  my $self  = new SWISS::BaseClass;
  
  $self->rebless($class);
  return $self;
}

sub fromText {
  my $class   = shift;
  my $textRef = shift;
  my $self    = new SWISS::Ref;

  my ($line, $tmp, @tmp);
  my ($token, $qualifiers, @qualifiers);
  my (%rc,%rx);
  my ($dbref, $dbid);
  my $match;

  # Remove indentation
  $self->{indentation}->{$1}++ while $$textRef =~ s/^ (\S+)/$1/m;

  # Parse RN
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RN'}/){
    my $rnline = $1;
    if ($rnline =~ /RN   \[(\d+)\]/){
      $self->RN("$1");
    }
    if ($rnline =~ /\]( ?\{.*\})/) {
      $self->{'evidenceTags'} = $1;
    }
  }
  else {
    if ($main::opt_warn) {
      carp "RN parse error, ignoring $$textRef";
    }
    return $self;	
  }
  
  # Parse RP
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RP'}/m){
    $match = $&;
    
    $line = SWISS::TextFunc->joinWith('', ' ', '(?<! )-', '(?:and|or|and/or) ',
                                      map {SWISS::TextFunc->cleanLine($_)}
                                          (split "\n", $match));
    $self->RP($line);
  }
  else {
    if ($main::opt_warn) {
      carp "RP parse error, ignoring $$textRef";
    }
  }

  # Parse RC
  undef %rc;
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RC'}/m){ 
    $match = $&;
    
    $line = join " ", map{SWISS::TextFunc->cleanLine($_)}(split /\n/m, $match);

    # drop trailing semicolon 
    $line =~ s/;$//;
    # don't drop 'AND', there are lines like
    # RC   STRAIN=HOK-01, FERM P-8705;
    # $line =~ s/\s*,\s*(AND\s+)*/, /g;
    
    @tmp = split(/;\s*/, $line);
    foreach $tmp (@tmp){
      ($token, $qualifiers) = $tmp =~ /^(\w+)\=(.*)/;

      # replace XXX AND YYY by XXX, AND YYY
      $qualifiers =~ s/(\w+)( AND)( \w+)$/$1,$2$3/;
      @qualifiers = split(/\,\s+(?!ECO:)/, $qualifiers);
      unless (grep(/$token/, @RCtopics)) {
	if ($main::opt_warn) {
	  carp "Ignoring unknown RC token $token";
	}
	next;
      }
      push@{$rc{$token}},  map {SWISS::RCelement->fromText($_)} @qualifiers;
    }
    $self->RC(\%rc);
  };

  # Parse RX
  undef %rx;
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RX'}/m){
    @tmp = map {SWISS::TextFunc->cleanLine($_)} (split /\n/m, $& );
    @tmp = map {split /\;(\s+|\z)/} @tmp; #some DOI may contain internal semicolons
    foreach $tmp (@tmp) {
      if (($dbref, $dbid) = $tmp =~ /(\w+)\=(.+)/) {
	$dbref = $1; $dbid = $2;
	# suppress duplicate dbxrefs
	unless (grep ($dbid, @{$rx{$dbref}})) {
	  push @{$rx{$dbref}}, $dbid;
	}
      }
    };
    $self->RX(\%rx);
  };

  #parse 'RX' MEDLINE=None
  if ($$textRef =~ /$SWISS::Ref::linePattern{'\*'}/m){
    $match = $&;
    $self->RX_comment($match);
  }

  # Parse RG
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RG'}/m){
    $line = SWISS::TextFunc->joinWith('', ' ', '(?<! )-', 'and ',
                                      map {SWISS::TextFunc->cleanLine($_)}
                                          (split "\n", $&));
    $self->RG($line);
  };

  # Parse RA
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RA'}/m){
    $self->RA(new SWISS::ListBase);
    $line = join ' ', map {SWISS::TextFunc->cleanLine($_)} (split /\n/m, $&);
    $self->RA->push (SWISS::TextFunc->listFromText($line, ',\s*', ';'));
  };

  # Parse RT
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RT'}/m){
    $match = $&;
    if ($match =~ /^\*\*/m) {
      $self->RT_comment($match);
    }
    else {
      my $line = SWISS::TextFunc->joinWith('', ' ', '(?<! )-', 'and ',
					   map {SWISS::TextFunc->cleanLine($_)}
					   (split /\n/m, $match));
      $line =~ s/(\A\")|(\";\s*\Z)//g; # Drop trailing spaces and embracing "";
      $self->RT($line);			
    }
  };
    
  # Parse RL
  if ($$textRef =~ /$SWISS::Ref::linePattern{'RL'}/m){
    $line = SWISS::TextFunc->joinWith('', ' ', '(?<! )-', 'and ', (map {SWISS::TextFunc->cleanLine($_)} (split /\n/m, $&)));
    # Drop trailing dot
    $line =~ s/\.$//;
    $self->RL($line);
  };
  
  $self->{_dirty} = 0;

  return $self;
}

sub toText {
  my $self = shift;

  my $newText = '';
  my ($rc, $topic);
  my $ra;
  my $longWordLength = $SWISS::TextFunc::lineLength - 8;

  # Format RN line
  if (defined $self->RN) {
    $newText = $newText . "RN   [" . $self->RN . "]" . $self->getEvidenceTagsString . "\n";
  }
  
  # Format RP line
  if (defined $self->RP) {
    $newText .= SWISS::TextFunc->wrapOn('RP   ','RP   ', $SWISS::TextFunc::lineLength, $self->RP,
        '(?<!-)\s+(?!\S{'.$longWordLength.'})'); # cut at a whitespace (not after a dash), not followed by long word (check: why!?) ...
  };

  # Format RC line
  if (defined $self->RC) {
    $rc = "RC   "; 
    my $rchash = $self->RC;
    foreach $topic (@RCtopics) {
      if (defined $rchash->{$topic}) {
        my @tmp = @{$rchash->{$topic}};
        next unless @tmp;
        $rc = $rc . "$topic=" . join(", ",  (map {$_->toText()} @tmp)) . "; ";
      } 
    }
    $newText .= SWISS::TextFunc->wrapOn('',"RC   ", $SWISS::TextFunc::lineLength, $rc, '; ', ', and ', ', ', '\s+')
      if $rc;
  };

  # Format RX line
  my $rx='';
  if (defined $self->RX) {

    my $rxhash = $self->RX;
    foreach $topic (@RXtopics) {
      if (defined(my $dbid_list = $rxhash->{$topic})) {
        $rx .= ' ' if length $rx;
        $rx .= ("$topic=$dbid_list->[0];");
      }
    }
  }
  #wrap only before DOI if the line is longer than 75 chars,
  #but don't wrap within the DOI number even if it is very long
  if (length $rx > $SWISS::TextFunc::lineLength - 5) {
	  $rx =~ s/(.*) /$1\nRX   /;
  }
  $newText .= 'RX   ' . $rx . "\n" if $rx; #don't use wrapOn

  if (defined $self->RX_comment) {
    $newText .= $self->RX_comment;
  };

  # Format RG line
  if (defined $self->RG) {
    my $rg = $self->RG;
    foreach my $r (split ';\s*', $rg) {# every consortium (sep by ;) should be on a distinct line (that shouldn't be wrapped unless max 256 char...)
        $newText .= SWISS::TextFunc->wrapOn('RG   ','RG   ', $SWISS::TextFunc::lineLengthMax, $r.';');  
    }
  }

  # Format RA line
  if (defined $self->RA) {
    $ra = join ", ", @{$self->RA->list};
    $ra .= ";";
    $newText .= SWISS::TextFunc->wrapOn('RA   ','RA   ', $SWISS::TextFunc::lineLength, $ra, '\,\s+');
  }

  # Format RT line
  if ($print_titles && defined $self->RT) {
    my $rt = $self->RT;
    $rt .= '.' unless $rt =~ m/[\.\?\!]$/;
    $rt = '"'.$rt.'";';
    $newText .= SWISS::TextFunc->wrapOn('RT   ','RT   ', $SWISS::TextFunc::lineLength, $rt);
  }
  elsif (defined $self->RT_comment) {
    $newText .= $self->RT_comment;
  };

  # Format RL line
  if (defined (my $rl = $self->RL)) {
    #after "cited by:", wrap line, and wrap again at every semicolon
    #before "(In) ", wrap line, and wrap again after it at every semicolon
  #NB: "cited by:" can be followed by "(In) "
    my @post_rl;
      if ($rl =~ s/(\(In\) .*)//) {
      @post_rl = split /(?<=;) /, $1;
    }
    my @rl;
      @rl = $rl if length $rl;
      if (my ($a, $b) = $rl =~ /(.*\bcited by:)\s*(.*)/) {
      @rl = ($a, split /(?<=;) /, $b);
    }
    push @rl, @post_rl;

    $rl[-1] .= "." if @rl;
    for (my $i=0; $i<@rl; $i++) {
      my @sep;
      #use comma (or parenthesis) separator in Author lists
      @sep = ',\s+|(?=\()' if $rl[$i] =~ /^\(In\) / or $rl[$i-1] =~ /cited by:$/;
      $newText .= SWISS::TextFunc->wrapOn('RL   ','RL   ', $SWISS::TextFunc::lineLength, $rl[$i],
            @sep, '\s+');
    }
  };

  $newText =~ tr/a-z/A-Z/ if $uppercase;

  # restore indentation
  if ($self->{indentation}) {
    $newText =~ s/^(?=\Q$_\E)/ /mg for keys %{$self->{indentation}};
  }

  # No reset of _dirty because the text is only returned, not written
  # back to an internal buffer.
  
  return $newText;
}


sub unpackRL {
  my $self=shift;
  
  my $rl = $self->RL;
  if (defined $rl) {
    if ($rl =~ /^(.*?)\s+(\w+):(\w+-\w+)\((\d+)\)$/){
      $self->{'journal'}= $1;
      $self->{'volume'} = $2;
      $self->{'pages'}  = $3;
      $self->{'year'}   = $4;
    } else {
      carp "RL parse error, ignoring $rl" if $main::opt_warn;
    }
  }
}
sub packRL {
  my $self=shift;

  my $journal = $self->journal || 'UNKNOWN JOURNAL';
  my $volume  = $self->volume  || '0';
  my $pages   = $self->pages   || '0-0';
  my $year    = $self->year    || '0';
  my $rl = "$journal $volume:$pages($year)";
  $self->RL($rl);
}

sub pubtype {
  my $self=shift;
  
  my $rl = $self->RL || return undef;

  return 'JOURNAL'        if $rl =~ /^[\w\.\s]+\s\d+:\d+-\d+\(\d+\)$/;
  return 'SUBMISSION'     if $rl =~ /^SUBMITTED/i;
  return 'UNPUBLISHED'    if $rl =~ /^UNPUBLISHED/i;
  return 'BOOK'           if $rl =~ /^\(IN\)/i;
  return 'THESIS'         if $rl =~ /^THESIS/i;
  return 'PATENT'         if $rl =~ /^PATENT/i;
  return 'JOURNAL'        if $rl =~ /\s\w*\d\w*:\w+-\w+\(\d+\)$/;
  return 'JOURNAL'        if $rl =~ /\s\w*\d\w*:\w+\(\d+\)$/;

  
  carp "Cannot parse publication type of '$rl'" if $main::opt_warn;
  return undef;
}

sub isPendingJournalArticle {
  my $self=shift;
  
  my $pt = $self->pubtype();
  return 0 if $pt ne 'JOURNAL';
  $self->unpackRL();
  return 1 if $self->volume eq 0;
  return 1 if $self->year == 0;
  return 1 if $self->pages eq '0-0';
  return 0;
}

sub get_MedlineID {
  my $self=shift;

  my %rx;
  my @mid;
  if (defined $self->RX){
    %rx = %{$self->RX};
    @mid = @{$rx{'MEDLINE'}};
  } 
  return wantarray ? @mid : shift @mid;
}

sub add_MedlineID {
  my $self=shift;
  my @medline_ids = @_;
  
  my %rx;
  if (defined $self->RX){
    %rx = %{$self->RX};
  } 
  my %already_there = map {$_,1} @{$rx{'MEDLINE'}};
  @medline_ids = grep {!$already_there{$_}} @medline_ids;
  push @{$rx{'MEDLINE'}},@medline_ids;
  $self->RX(\%rx);
}

sub add_Author {
  my $self=shift;
  my @authors = @_;
  
  unless (defined $self->RA){
    $self->RA(new SWISS::ListBase);
  } 
  $self->RA->add(@authors);
}

sub rc_sort {
  my $self=shift;

  if (defined $self->RC) {
    for my $topic (@RCtopics) {
      if (my $rclist = $self->RC->{$topic}) {
        if (@$rclist > 1) {
				  # remove leading "and"
          map {$_->cleanText} @$rclist;
    
          # sort
          @$rclist = sort {lc $a->text cmp lc $b->text || $a->text cmp $b->text} @$rclist;
    
          # add "and" back in
          $rclist->[-1]->text("and " . $rclist->[-1]->text) if @$rclist > 1;
          @{$self->RC->{$topic}} = @$rclist;
          $self->{_dirty} = 1;
        }
      }
    }
  }
}

1;

__END__

=head1 Name

SWISS::Ref.pm

=head1 Description

B<SWISS::Ref> represents a single reference of a SWISS-PROT + TREMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<RN>

The reference number.

=item C<RP>

The RP line(s), unwrapped as a string.

=item C<RC>

Zero or more RC lines. 

Data structure: 
{Token}[qualifier1, qualifierN].

A hash of arrays. Hash keys are the RC tokens, array elements are the qualifiers for that token.

=item C<RX>

References to bibliographic databases.

Data structure: 
{Database}[identifier1, identifierN].

A hash of arrays. Hash keys are the names of bibliographic databases, array elements are the identifiers of the reference for that database.

=item C<RG>

The RG line(s), unwrapped as a string.

=item C<RA>

The list of Authors.

An object of type SWISS::ListBase.

=item C<RT>

The publication title, unwrapped as a string.

=item C<RL>

The RL line.

Data structure:
String.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head2 Writing methods

=over

=item add_MedlineID

Add a RX line 'MEDLINE; nnnnnnnn.' to the reference.

=item add_Author

Add an author to the RA line of the reference.

=item rc_sort

Sort elements of the RC line alphabetically.
