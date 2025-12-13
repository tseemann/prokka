package SWISS::TextFunc;

use vars qw(
  $AUTOLOAD @ISA @EXPORT_OK
  @lineObjects
  @linePattern %linePattern
  $evidencePattern $evidencePatternOld $evidencePatternNew $evidencePatternAsSep $evidencePatternReversed
  $textWrapPattern1 $textWrapPattern2
  $lineLength $lineLengthMax $lineLengthStar $lineLengthSQ
  );
use Exporter;
use Carp;
use strict;

BEGIN{
  @EXPORT_OK = qw(wrap);
  @ISA = ( 'Exporter' );

  @lineObjects = ('IDs', 'ACs', 'DTs', 'DEs', 'GNs', 
		  'OSs', 'OGs', 'OCs', 'OXs', 'OHs',
		  'Refs', 'CCs', 'DRs', 'PE', 'KWs', 'FTs', 'Stars', 'SQs');

  @linePattern = ('^( ?ID   .*\n)+(\*\*   .*\n)*',
		  '^( ?AC   .*\n)+(\*\*   .*\n)*',
		  '^( ?DT   .*\n){3}', 
		  '^( ?DE   .*\n)+', 
		  '^( ?GN   .*\n)+', 
		  '^( ?OS   .*\n)+', 
		  '^( ?OG   .*\n)+', 
		  '^( ?OC   .*\n)+', 
		  '^( ?OX   .*\n)+', 
		  '^( ?OH   .*\n)+', 
		  # Complex expression for Reference blocks
		  '^( ?R.   .*\n)+(( ?R.   .*\n)|( ?\*\*   .*\n))*( ?R.   .*\n)+',
		  '^( ?CC   .*\n)+',
		  # The block of DR lines may contain ** lines, except at the beginning, e.g.
		  # **   PRINTS; PR01217; PRICHEXTENSN; FALSE_POS_1.
		  '^( ?DR   .*\n)+( ?DR   .*\n| ?\*\*   \w+;.+\n)*',
		  '^( ?PE   .*\n)+', 
		  '^( ?KW   .*\n)+', 
		  '^( ?FT   .*\n)+', 
		  # Take a complex extended expression to take the
		  # LAST ** line group as the annotator's section
		  # NB: the 'Stars' comment is used to identify the hash key as 'St' in Stars.pm
		  '^(?#Stars)((\*\*\s*\n)|(\*\*   \#.*\n))+(\*\*.*\n)*(?=((SQ   .*\n)(     .*\n)+)?(\/\/\n))',
		  # The sequence contains two line types and is at the end.
		  '^(SQ   .*\n)(     .*\n)+(?=\/\/\n)'
		  );
  my ($line, $lineId);
  foreach $line (@linePattern) {
    ($lineId) = $line =~ /(\w\S)/;
    $linePattern{$lineId} = $line;
  }
 
  # The general pattern for evidence tags, .Sets $1 to the evidence tag
  $evidencePattern         = ' ?\{((?:ECO:\d+[^,}]+(?:, )?)+|(?:E[ACIP]\d+,?)+)\}';
  $evidencePatternOld      = '\{((?:E[ACIP]\d+\,?)+)\}';
  $evidencePatternNew      = ' \{((?:ECO:\d+[^,}]+(?:, )?)+)\}';
  $evidencePatternAsSep    = '(?:\. | )?\{((?:ECO:\d+[^,}]+(?:, )?)+)\}(?:\. )?';
  
  # and its reversed form for the parsing of the DE lines TODO: check DE parsing!
  $evidencePatternReversed = '\}(\,?\d+[ACIP]E)*\{';

  # General pattern and last-resort pattern for wrapping text fields:
  # Wrap either at a whitespace that is not following a dash; or at a dash
  # that is followed either by a letter/digit or an opening round or square
  # bracket (so as not to cut at "->" or "--" or "-," etc) but not preceded by a
  # space (because such dash might indicate a suffix).
  $textWrapPattern1 = '(?<!-)\s+|(?<! )-(?=[A-Za-z0-9\(\[])';
  # as a last resort cut at a dash that is not part of an arrow or double-dash.
  # (and not followed by a space)
  $textWrapPattern2 = '-(?![>\- ])';

  $lineLength = 80;
  $lineLengthMax = 255;
  $lineLengthStar = 32766;
  $lineLengthSQ = 60;
}

sub listFromText {
    my $class = shift;
    my $text = shift;
    my $sep = shift;
    my $end = shift || $sep;

    chomp $text;          # remove \n from end of text
    $text =~ s/^$sep//;   # remove separator at the beginning of the text
    $text =~ s/$end$//;   # remove separator at the end of the text

    return split /$sep/, $text;
}

sub textFromList {
    my $class = shift;
    my $list  = shift;
    my $sep   = shift;
    my $end   = shift;
    my $width = shift;

    my $text  = (join $sep, @{$list}) . $end; # produce one funck off long string
    # work out how many characters can be per line
    $width -= length $sep;                   

    while($text =~ m/(.{1,$width}(($sep)|($)))/g) {
	push @_, $1;
    }

    return @_;
}

sub wrapText {
    my $class = shift;
    my $text  = shift;
    my $width = shift;

    $text = '' unless $text;
    while($text =~ m/(.{1,$width})(\s+|$)/g) {
	push @_, $1;
    }

    return @_;
}

sub wrapOn {
  my ($class, $prefix1, $prefix2, $columns, $text, @separators) = @_;
  my ($newText, $prefix, $width, $trailingBlanks);
  my ($lineText, $sepText, $match, $postMatch);

  $newText = '';

  # prefix1: first line "prefix", prefix2: other lines "prefix", columns: max size, text: text to add and wrap after prefix 1
  push @separators, $textWrapPattern1, $textWrapPattern2, ''; # add default sep. to provided separators n.b. @separators might be empty: as a last resort, wrap anywhere

  # eventually use multiple separators (for some FT lines); triggered when provided separators first elem is array ref!...
  my ($separator1, $border, $separator2, $longWordChar);
  if (ref $separators[0] eq "ARRAY") {
    ($separator1, $border, $separator2, $longWordChar) = @{$separators[0]};
    $separators[0] = $separator1;
  }


  $prefix=$prefix1;
 TEXT:while ($text) {

    # switch between using separator1 or separator2 depending on border (for some FT lines)
    $width = $columns - length ($prefix);
    if (defined($separator1) and $separators[0] eq $separator1) { #fugly! happen when $separators[0] eq "ARRAY"; "means": border is (/should have been!) set
    # if border is found in line to wrap (up to width) or in already wrapped lines
    # use separator2 instead of separator1!
    # e.g. 
    # FT   VARIANT     222    222       L -> P (in CLN1; late infantile blablabla)
    # separator1 = '(?!\>)\s*', separator2 = "/|$SWISS::TextFunc::textWrapPattern1" border = '[{(]'
    # so here separator2 will be used has there is a "()" = textFunc::textWrapPattern1 = will wrap on ws before bla...
    # wheras with e,g. 
    # FT   CONFLICT    245    303       LKNNTITTHPKFQTITPINNSIIFFNSRCRHEVMSVVCPSRPPAAAESPSMH -> GLPKGSVPPAAAESPSMHRKQELDSSQAPQQPGKPPDPGRPTQPGLSKSR
    # separator1 will be use = (?!\>)\s*: wrap anywhere (at max witdh) if not after a > or on first space(s)  = will wrap inside first "seq"
      if (($newText =~ /$border/)
	  ||
	  (substr($text, 0, $width) =~ /$border/)
	 ) {
	$separators[0] = $separator2;
      }
    };

    for (my $i=0; $i<@separators; $i++) {
      $width = $columns - length ($prefix); # initialize each time
      if (length($text) <= $width) { # no wrapping needed
        $newText = $newText . $prefix . $text . "\n";
        $text = '';
        next TEXT;
      }
      else { # needs wrapping
        while (($lineText, $sepText) = 
            $text =~ /\A(.{1,$width})($separators[$i]|\Z)/) {
          $match = $&;
          $postMatch = $';
          my $spaces = $match =~ s/(\s+)\Z// ? $1 : "";
          if (length($match) > $width) {
            # The separator extends
            # beyond the maximal line length. Retry with shorter $width. 
            $width--;
          }
          else {

            if (defined $longWordChar) {
              
              # if a long word is found, cut it anywhere and append as much of it as possible to the uppermost line...
              
              if ($postMatch =~ /^$longWordChar {$width}/x) {
              
                my $cutPos = $width - length($match) - length($spaces);

                #  ... however, try to cut the long word at any separators of lower priority than the current one,
                # except the empty last-resort separator
                for (my $j=$i+1; $j<@separators-1; $j++) {
                  # TODO: this is currently only optimal for fixed separators
                  # of length 1 ($sepLength = 1)
                  my $sepLength = 1;
                  my $w0 = $cutPos - $sepLength;
                  my $w1 = $w0 > 0 ? $w0 : 0;
                  if ($postMatch =~ /^(\S{0,$w1}$separators[$j])/) {
                    $cutPos = length($1);
                    last;
                  }
                }

                # ok, now do the splicing
                if ($cutPos>0) {
                  my $substr = substr($postMatch, 0, $cutPos);
                  substr($postMatch, 0, $cutPos) = "";
                  $match .= $spaces . $substr;
                }
              }
            }

            $newText = $newText . $prefix . $match . "\n";
            $text = $postMatch;
            $prefix=$prefix2; 
            next TEXT;
          }
        }
      }
    };

    # Wrapping failed    
    if ($main::opt_warn) {
      carp "TextFunc::wrapOn: Cannot wrap $text";
    };
    $newText = $text . "\n";
    $text = '';
  }
  $newText =~ s/ +$//mg;
  return $newText;
}

sub cleanLine {
    my $class = shift;
    my $text  = shift;

    # Drop trailing spaces
    $text =~ s/\s+$//;
    chomp($text);
    if(length($text) != 2) {
	$text = substr $text, 5;
    } else {
	$text = undef;
    }

    return $text;
}

sub joinWith {
  my $self = shift;
  my($text, $with, $noAddAfter, $addBefore, @list) = @_;
  
  unless ($text) {
    $text = shift @list;
  };

  for my $line (@list) {
    unless ($text =~ /$noAddAfter$/ && $line !~ /^$addBefore/) {
      $text .= $with
    };
    $text .= $line;
  }
  return $text;
}

sub insertLineGroup {
  my $class   =  shift;
  my $textRef = shift;
  my $text    = shift;
  my $pattern = shift;
  my $found   = -1;
  my $i;
  
  # The easy case: Replace a text block with a new one.
  if ($$textRef =~ /$pattern/m) {
    $$textRef = $` . $text . $';
    return 1;
  }

  # Nothing to replace found. Seek insertion place.
  for ($i = $#linePattern; $i>=0; $i--) {
    if ($pattern eq $linePattern[$i]) {
      $found = $i;
      last;
    }
  }
  if ($found == -1) {
    $main::opt_warn && carp "Could not insert $text into $$textRef";
    return 0;
  }
  for ($i = $found; $i>=0; $i--) {
    if ($$textRef =~ /$linePattern[$i]/m) {
      $$textRef = $` . $& . $text . $';
      return 1;
    }
  }
  
  if (defined $main::opt_warn) {
  
    $main::opt_warn >2 && carp "Prepended $text to $$textRef";
  }
  
  $$textRef = $text . $$textRef;
  return 0;
}

sub uniqueList {
  my $class = shift;

  my @oldList = @_;
  my @newList;
  my $element;

  foreach $element(@oldList) {
    unless (grep{$_ eq $element} @newList) {
      push @newList, $element;
    }
  };

  return @newList;
}


sub currentSpDate {  
  my ($dummy, $mday, $month, $year);
  
  my %month2number =  
    ('1'=>'JAN', '2'=>'FEB', '3'=>'MAR', '4'=>'APR', 
     '5'=>'MAY', '6'=>'JUN', '7'=>'JUL', '8'=>'AUG', 
     '9'=>'SEP', '10'=>'OCT', '11'=>'NOV', '12'=>'DEC');
  
  ($dummy, $dummy, $dummy, $mday, $month, $year, $dummy, $dummy, $dummy) 
    = localtime (time);
  if ($mday < 10) {
    $mday = '0' . $mday;
  }
  $month = $month2number{$month+1};
  $year += 1900;

  return "$mday-$month-$year";
}





#
# Functions used to cleanup entries in annotators' jobs
# Author : Alexandre Gattiker <gattiker@isb-sib.ch>
#

#removes wild ** comments throughout an entry, except after a DR line
#they can be reinserted again, based on the line that follows them.
#returns an pointer to a hash of "following lines" => "wild comment"
sub removeInternalComments {
	my $textRef   = shift;
	my $newText   = "";
	my %lines;
	my $afterACID = 0;
	my $inEnd     = 0;
	my $inRef     = 0;
	my $inDR      = 0;
	my @comments;
	#remove everything before the ID line
	if ($$textRef =~ s/(.*?)^ID/ID/sm) {
		$lines{_start} = $1;
	}
	for (split /\n/, $$textRef) {
		$_ .= "\n";
		if ($inEnd || /SOURCE SECTION|INTERNAL SECTION|ANNOTATOR'S SECTION/) {
			#comments right before source section should go just inside
			$inEnd++;
			my (@textComments, @otherComments);
			for my $comment (@comments) {
				if ($comment =~ /\w/) {
					push @textComments, $comment;
				} 
				else {
					push @otherComments, $comment;
				}
			}
			$newText .= join '', @otherComments, $_, @textComments;
			undef @comments;
			next;
		}
		if (/^AC|^ID/) {
			$afterACID=1;
			if (@comments) {
				$lines{$_}=[@comments];
				splice @comments;
			}
			$newText .= $_;
			next;
		}
		#annotators' comment lines begin either with ** or ++
		elsif (/^ ?\*\*|^ ?\+\+/ && !$afterACID
			and (!$inRef or !/NO TITLE|=None/)
			and !($inDR and /^\*\*   \S+; \S+; \S+; /)
			) {
			push @comments, $_;
		}
		else {
			$afterACID=0;
			if (@comments and /(\S.*)/) {
				$lines{$1}=[@comments];
				splice @comments;
			}
			$newText .= $_;
			next;
		}
	}
	continue {
		$inRef = /^R/;
		$inDR = /^DR/ || ($inDR && /^\*/);
	};
	$$textRef=$newText;
	return \%lines;
}

#does the opposite...
#returns an array with the internal comments that could not be restored at their proper position.
#the caller should do something like $entry->Stars->ZZ->add them.
sub restoreInternalComments {
	my($textRef, $lines)=@_;

	#comments going before ID line
	my $before = delete $lines->{_start};

	#other comments : add before the relevant line
	my @newText;
	for my $line (split /(?<=\n)/, $$textRef) {
		if ($line =~ /(\S.*)/ and my ($comments) = delete $$lines{$1}) {
			push @newText, _wrapInternalComments(@$comments);
		}
		push @newText, $line;
	}

	#remaining comments : try to add before the relevant block
	my @newText2;
	for my $line (@newText) {
		if ($line =~ /^\s*(\w\w)/) {
			my $lineTag = $1;
			for my $prevline (keys %$lines) {
				if ($prevline =~ /^\s*($lineTag)/) {
					my $comments = delete $$lines{$prevline};
					push @newText2, _wrapInternalComments(@$comments);
				}
			}
		}
		push @newText2, $line;
	}

	$$textRef=$before . join "", @newText2;

	#return comments that could not be inserted
	return map{s/^\s*\*\*\s*//; s/\n$//; $_} map {@$_} values %$lines;
}

#wrap internal comments at 75 characters
sub _wrapInternalComments {
	foreach (@_) {
		my ($prefix) = s/^(\W+)// ? $1 : "";
		s/\s+$//;
		$_ = wrapOn (undef, $prefix, $prefix, $SWISS::TextFunc::lineLength, $_, '\s+')
	}
	@_;
}

sub toMixedCase {
	my ($text, @regexps) = @_;
	my $ok_regexp;
	for my $regexp (@regexps) {
		#This regexp is made complex by the need to convert e.g. "B0690/B0691" to "b0690/b0691"
		$text =~ s!(?:^|\G)($regexp)($|\/)!
			my @char = split //, $1;
			my $postfix = substr $text, $-[-1], $+[-1] - $-[-1]; #this fetches the content of the '($|\/)' part of the regexp as the last matched subgroup (i.e. the possible slash), see man perlre for "@-" for an explanation
			if ($1 =~ /^($regexp)$/) { #if it matches the regexp case-sensitively, no need to convert
					$1 . $postfix; #return value
			}
			else {
				my $num_letter=0;
				my @letter_pos;
				for (my $i=0; $i<@char; $i++) {
					$letter_pos[$i] = (uc ($char[$i]) ne lc $char[$i]) ? 1 : 0;
					$num_letter += $letter_pos[$i];
				}
				my $string_ok;
				for (my $binary=0; $binary<2**$num_letter; $binary++) { #combinatorially change casing of each letter
					my $string = "";
					my $j=0;
					for (my $i=0; $i<@char; $i++) {
						if ($letter_pos[$i]) {
							my $mask = 1<<$j;
							my $bin_value = ($binary & $mask) >> $j;
							$string .= $bin_value ? uc($char[$i]) : lc($char[$i]);
							$j++;
						}
						else {
							$string .= $char[$i];
						}
					}
					$string_ok = $string, last if $string =~ /^(?:$regexp)$/; #case-sensitive match
				}
				if (defined $string_ok) {
					$string_ok . $postfix; #return value
				}
				else {
					#this should never happen
					warn "INTERNAL ERROR: Could not find correct casing for ".join("",@char)." ($regexp)";
					join("",@char) . $postfix; #return value
				}
			}
		!egi or next;
		$ok_regexp = $regexp;
		last;
	}
	return wantarray ? ($text, $ok_regexp) : $text;
}


1;

__END__

=head1 NAME

SWISS::TextFunc

=head1 DESCRIPTION

This module is designed to be a repository of functions that are
repeatedly used during parsing and formatting of SWISS-PROT/TREMBL lines.
If more than two line types need to do aproximately the same thing
then it is probably in here.

All functions expect to be called as package->function(param list)

=over

=item listFromText

Takes a piece of text, a seperator regex and a seperator that may appear at the end.
Returns an array of items that were seperated in the text by that seperator.  Takes care of
null items (looses them for you).

=item textFromList

Takes an array of items, a separator, a terminating string, and a line width.
Returns an array of strings, each ending with the separator or the terminator with
a width less than or equal to the width specified.

Seems to do the wrong thing for references - not sure why.  
Don't use it for that.

=item wrapText

Takes a string and a length.  Returns an array of strings which are shorter or equal
in length to length, spliting the string on white space.

=item wrapOn ($firstLinePrefix, $linePrefix, $colums, $text[, @separators])

Wraps $text into lines with at most $colums colums. Prepends the
prefixes to the lines. @separators is a list of expressions on which
to wrap. The expression itself is part of the upper line. 

If no @separators are provided, the $text is wrapped at whitespace
except in EC/TC numbers or at dashes that separate words.

First tries to wrap on the first item of @separators, then the next
etc.  If no wrap on any element of @separators or whitespaces is
possible, wraps into lines of exactly length $colums. 

A special case is that the first item of @separators may be a reference
to an array. This is used internally for wrapping FT VARIANT-like lines.

Example:

 wrapOn('DE ', 'DE ', 40, 
        '14-3-3 PROTEIN BETA/ALPHA (PROTEIN KINASE C INHIBITOR PROTEIN-1)', 
        '\s+') 
 returns ['14-3-3 PROTEIN BETA/ALPHA (PROTEIN ', 
          'KINASE C INHIBITOR PROTEIN-1)']
 wrapOn('DE ', 'DE ', 40, 
        '14-3-3 PROTEIN BETA/ALPHA (PROTEIN KINASE C INHIBITOR PROTEIN-1)', 
        ' (?=\()', '\s+')
 returns ['14-3-3 PROTEIN BETA/ALPHA ', 
          '(PROTEIN KINASE C INHIBITOR PROTEIN-1)']

=item cleanLine

Remove the leading line Identifier and three blanks and trailing spaces from an SP line. 

=item joinWith ($text, $with, $noAddAfter, @list)

Concatenates $text and @list into one string. Adds $with between the 
original elements, unless the postfix of the current string is $noAddAfter. 
This is used to avoid inserting blanks after hyphens during concatenation. 
So unpleasant strings like 'CALMODULIN- DEPENDENT' are avoided. Unfortunately 
a correct reassembly of strings like 'CARBON-DIOXIDE' is not done.

=item insertLineGroup ($textRef, $text, $pattern)

Inserts text block $text into the text referred to by $textRef. $text will replace the text block in $textRef matched by $pattern.

=item uniqueList (@list)

Returns a list in which all duplicates from @list have been removed. 

=item currentSpDate

returns the current date in SWISS-PROT format

=item toMixedCase($text, @regexps)

Convert a text to mixed case, according to one or more regular expressions.
In scalar context, returns the new text; in array context, also returns
the regexp with which the change was performed, or undef on failure.
See corresponding item in SWISS::GN for more details.

=back
