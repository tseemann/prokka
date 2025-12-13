package SWISS::FTs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields %KEYORDER);

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

#initialization code: stuff DATA into hash
{
  # Leading and trailing spaces are MANDATORY!
    local $/="\n";
    my $index=0;
    my $line;
    while (defined ($line=<DATA>)) {
        $line =~ s/\s+\z//;
        $index++;
        $KEYORDER{$_} = $index for split /\s+/, $line;
    }
    close DATA;
}

sub new {
    my $ref = shift;
    my $class = ref($ref) || $ref;
    my $self = new SWISS::ListBase; # FTs is a List of FT that itself is [ key, from, to, description/note, qualifier(legacy), id, isoform, ev ]

    $self->rebless($class);
    return $self;
}

sub fromText {
    my $class = shift;
    my $textRef = shift;
    my $self = new SWISS::FTs;
    my $line;
    my $indentation = 0;
    my ($key, $from, $to, $description0, $id, $ev, $qualifier, $isoform );  # attributes of one feature
    my $keyval = {}; # extra (2022.03 format) attributes/fields
    my $current_att_type = "";

    if ( $$textRef =~ /($SWISS::TextFunc::linePattern{'FT'})/m ) {
        foreach $line ( split /\n/m, $1 ) {
            my $_indent = $line =~ s/^ //;
            $line = SWISS::TextFunc->cleanLine($line);

            if ( $line =~ /^(\S+)\s+(?:([^\s:]+)?:)?(?:([^\s.]+?)\.\.)?(\S+)$/ ) { # first line of FT in new (2019.11) format
                process_current_ft( $self, $indentation, $key, $from, $to, $description0, $qualifier, $id, $isoform, $ev, $keyval ) if $key; # process previous FT
                $key = $1; $isoform = $2 || "" ; $from = $3 || $4; $to = $4; $description0 = ""; $qualifier = "", $id = ""; $ev = "";
                $current_att_type = "";
                $keyval = {}
            }
            elsif ( $line =~ /^(\S+)\s+(\S+)\s+(\S+)\s*(.*)$/ ) { # first line of old/classical-format FT
                process_current_ft( $self, $indentation, $key, $from, $to, $description0, $qualifier, $id, $isoform, $ev, $keyval ) if $key; # process previous FT
                $key = $1; $isoform = undef;     $from = $2;       $to = $3; $description0 = $4;
                $current_att_type = "";
                $keyval = {}
            }

            elsif ( $line =~ /^\s+\/note="([^"]+)/ ) { # continuing new-format FT, note start
                $description0 = $1;
                $current_att_type = "note";
            }
            elsif ( $line =~ /^\s+\/id="([^"]+)/ ) { # continuing new-format FT, id start
                $id = $1;
                $current_att_type = "id";
            }
            elsif ( $line =~ /^\s+\/evidence="([^"]+)/ ) { # continuing new-format FT, evidence start
                $ev = $1;
                $current_att_type = "evidence";
            }
            elsif ( $line =~ /^\s+\/(\w+)="([^"]+)/ ) { # continuing new-new-format FT, field start (non id/evidence/note)
                $keyval->{ $1 } = $2;
                $current_att_type = $1;
            }
            elsif ( $current_att_type eq "note" ) { # continuing new-format FT, continuing note
                $line =~ s/^\s+|"?\s*$//g;
                $description0 = SWISS::TextFunc->joinWith( $description0, ' ', '(?<! )[-/]', '(?:and|or|and/or) ', $line );
            }
            elsif ( $current_att_type eq "id" ) { # continuing new-format FT, continuing id p.s. should not happen, id likely fits a single line
                $line =~ s/^\s+|"?\s*$//g;
                $id .= $line;
            }
            elsif ( $current_att_type eq "evidence" ) { # continuing new-format FT, continuing evidence
                $line =~ s/^\s+|"?\s*$//g;
                $ev = SWISS::TextFunc->joinWith( $ev, ' ', '(?<! )[-/]', '(?:and|or|and/or) ', $line );
            }
            elsif ( $current_att_type ) { # continuing new-new-format FT, continuing extra field
                $line =~ s/^\s+|"?\s*$//g;
                my $fieldvalue = $keyval->{ $current_att_type };
                $keyval->{ $current_att_type } = SWISS::TextFunc->joinWith( $fieldvalue, ' ', '(?<! )[-/]', '(?:and|or|and/or) ', $line );
            }
            elsif ( !defined( $isoform ) && $line =~ /^\s+(.*)$/ ) { # continuation of old/classical-format feature description
                $description0 = SWISS::TextFunc->joinWith( $description0, ' ', '(?<! )[-/]', '(?:and|or|and/or) ', $1 );
            }

            else {
                if ($main::opt_warn) {
                    carp "FT line $line parse error.";
                }
            }
            
            $indentation += $_indent;
        }

        process_current_ft( $self, $indentation, $key, $from, $to, $description0, $qualifier, $id, $isoform, $ev, $keyval ) if $key; # finalize (last FT)
    }
    else {
        $self->initialize;
    }
  
    $self->{_dirty} = 0;

    return $self;
}

sub process_current_ft() {
    my $fts                                                                                      = shift;
    my ($indentation, $key, $from, $to, $description0, $qualifier, $id, $isoform, $ev, $keyval ) = @_;
    my $description = _cleanDescription( $key, $description0 );
    $description .= "." if ( defined( $isoform ) && $key eq "MUTAGEN" ); # new format MUTAGEN: add back "." (only FT supposed to be a sentence)
    my $ft = defined( $isoform ) ?
                [ $key, $from, $to, $description, $qualifier, $id, $isoform, '{ '.$ev.'}', $keyval ] : # new format (>=2019.11). Yes!: add { } to ev so that it's compatible with old ListBase EvidenceTag methods + 2022_03: extra keyval...
                [ $key, $from, $to, _unpack( $description )                                        ];  # old format (all sub fields are inside raw description: extract them first with _unpack)
    push @{$fts->list()}, $ft;
    push @{$fts->{indentation}}, [$ft->[0], $ft->[1], $ft->[2], $ft->[3], $ft->[4], $ft->[5], $ft->[6], $ft->[7], $ft->[8] ] if $indentation;
    $indentation = 0;
}

sub _unpack { # extract qualifier (legacy), (ft)id & ev from old format (<2019.11) description
    my $text = shift;
    my ($qual, $ftid, $evidenceTags) = ('','','{}');

    return ('','','', undef, '{}') unless $text;

    if ($text =~ s/(\/FTId=\S+)$//){
        $ftid = $1;
        $ftid =~ s/\.$//;
        $text =~ s/[\n\.\s]+$//sg;
    }

    # Parse out the evidence tags
    if ($text =~ s/($SWISS::TextFunc::evidencePattern)//) {
        $evidenceTags = $1; # p.s. with new evtag format $1 = ' {ECO:...}' (with extra space), old format is e.g. '{EC1}'
        $evidenceTags =~s/: /:/ if $evidenceTags =~/ECO:/; # fugly: now evtag can be wrapped on : (to solve too long-because-of-ev FT lines problem!), will be unwrapped with an extra space after : (as I can not use variable lenght negative lookback in regex when using joinWith)
    }

    # old-style Swiss-Prot evidence (qualifier)
    if ($text =~ s/ \((BY SIMILARITY|POTENTIAL|PROBABLE)\)$//i){
        $qual = $1;
    }
    elsif (grep {$_ eq uc $text} ('BY SIMILARITY', 'POTENTIAL', 'PROBABLE')) {
        $qual = $text;
        $text = "";
    }

    $text =~ s/[\n\.\s]+$//sg;

    return ($text, $qual, $ftid, undef, $evidenceTags);
}


sub toText {
    my $self = shift;
    my $textRef = shift;
    my $newText = '';

    if ($#{$self->list()}>-1) {
        $newText = join('', map {$self->_FTtoText($_, @{$_})} @{$self->list()});
    };

    $self->{_dirty} = 0;

    return SWISS::TextFunc->insertLineGroup($textRef, $newText, $SWISS::TextFunc::linePattern{'FT'});
}  


# remove wrongly inserted ' ' in description of CONFLICT, VARIANT, VAR_SEQ and VARSPLIC

sub _cleanDescription {
    my ($key, $description) = @_;
    # parts of the description of CONFLICT, VARIANT, VAR_SEQ and VARSPLIC
    my ($sequence, $ref);

    # Remove trailing dots and spaces
    $description =~ s/[\s\.]+$//;

    if (($key eq 'CONFLICT')
        ||
        ($key eq 'VARIANT')
        ||
        ($key eq 'VAR_SEQ')
        ||
        ($key eq 'VARSPLIC')) {
      # The * is allowed as part of the description for cases like
      # AC Q50855: AVWKA -> R*SVP

        if ($description !~ /^Missing/) {
            if (($sequence, $ref) = $description =~ /([A-Z \-\>\*]+)(.*)/) {
                $sequence =~ s/(?<! OR) (?!OR )//gm;
                $sequence =~ s/\-\>/ \-\> /;
                $sequence .= ' ' if $ref && $ref !~ /^\{/;
                $description = $sequence . $ref;
            }
        }
    }

    if ($key eq 'MUTAGEN') {
        if ($description !~ /^Missing/) {
            if (($sequence, $ref) = $description =~ /([A-Z \-\>\*,]+)(.*)/) {
                $sequence =~ tr/ //d;
                $description = $sequence . $ref;
            }
        }
    }

    return $description;
}


sub _FTtoText { # serialize/build (with correct wrapping) a FT from its details/fields
    my ($self, $ft, $key, $from, $to, $description, $qualifier, $ftid, $isoform, $ev, $keyval ) = @_;
        # fugly!? uses both ($ft) the FT array-ref (an FTs element) and key, from, to etc (that could be extracted from the FT array-ref)!
        # $ft is only considered/used for its indentation (?) field !
        # To use this method to serialize individual existing FT array do: <FTs-obj-ref> -> _FttoText( <FTarrayref>, @{ <FTarrayref> } )  !
        # To use this method to serialize de novo / artificial FT do: <FTs-obj-ref> -> _FttoText( [], <key>, <from>, <to>, ... )
    my ($head, $text);

    my $is_new_format = defined( $isoform );

    $text = '';
    if ( $is_new_format ) {
        my $isof = $isoform ? $isoform.":" : "";
        $head = sprintf("FT   %-8s        %s",  $key, $isof.$from ) . ( $from eq $to ? "" : "..".$to );
    }
    else { $head = sprintf("FT   %-8s  %5s  %5s       ",  $key, $from, $to ); }

    if (!$is_new_format && $qualifier) {
        if (length $description){
            $description = "$description ($qualifier)";
        } else {
            $description = $qualifier;
        }
    } # e.g. (legacy) " (By similarity)"

    if ( !$is_new_format && $ev && $ev ne '{}' ) { # add the evidence tags to description (<2019.11 format)
        if ( $ev =~/ECO:/ && $description ) { # with modern evtag in old/classic <2019.11 format put . before evtag (if the desc core is not empty)
            $description .= "." . $ev; # p.s. extracted (_unpack) ev from description look like " {ECO:0000250}." (!)
        }
        else {
        	$description .= $ev; # old EBI ev style
        }
    }

    if ( !$is_new_format ) { # old format:
        if (  length $description ) { # Add a dot at the end if the description does not consist only of evidence tags  (<2019.11 format)
            $text = $description;
            unless ($description =~ /\A$SWISS::TextFunc::evidencePatternOld\Z/) {
                $text .= '.';
            }
        } else { # Text must not be empty, otherwise the wrapping will return ''
            $text .= ' ';
        }
    }

    if ( $is_new_format ) {
        my $pad = "FT                   ";
        $ev =~ s/^\{ |\}$//g; # remove added { } to ev so that it's compatible with old ListBase EvidenceTag methods
        my $xfields = "";
        if ( keys( %$keyval ) ) {
            foreach my $k ( sort { $a cmp $b } keys( %$keyval ) ) {
                $xfields .= _wrapField( "", $pad, $pad, "/$k=\"".$keyval->{$k}."\"" )
            }
        }
        $text = $head."\n".
            $xfields .
            ( $description ? _wrapField( $key, $pad, $pad, "/note=\"".$description."\"" ) : "" ).
            ( $ev          ? _wrapField( "",   $pad, $pad, "/evidence=\"".$ev."\"" ) : "" ).
            ( $ftid        ? $pad."/id=\"".$ftid."\"\n" : "" )
    }
    else {
        $text = _wrapField( $key, $head, "FT                                ", $text );
    }

    if ( !$is_new_format && length $ftid ) { # add a /FTId line if necessary (<2019.11 format)
      $text .= "FT                                $ftid.\n";
    }
 
    # reinsert indentation
    if ($self->{indentation}) {
        for my $indented (@{$self->{indentation}}) {
            next unless $ft->[0] eq $indented->[0]
              and $ft->[1] eq $indented->[1]
              and $ft->[2] eq $indented->[2]
              and $ft->[3] eq $indented->[3];
            $text =~ s/^/ /mg;
            last;
        }
    }
    return $text;
}

sub _wrapField {
    my ( $key, $prefix, $prefix2, $text ) = @_;
    if ( $key =~ /CONFLICT|VARIANT|VAR_SEQ|VARSPLIC/ ) {
        $text = SWISS::TextFunc->wrapOn($prefix,
            $prefix2,
            $SWISS::TextFunc::lineLength, $text,
            ['(?!\>)\s*', '[{(]', "/|$SWISS::TextFunc::textWrapPattern1", '[^\s\-/]'],
            "/|:(?=[^}]+\\})|$SWISS::TextFunc::textWrapPattern2"
        );
        # wrap on ws not after > or if already wrapped/current line has { or (: wrap on "/" or some ws or "-",
        # then "/" or ":" inside evtags or some "-"
    }
    elsif( $key eq "MUTAGEN" ) {
        my $sep_seqchange_re = $SWISS::TextFunc::lineLength == 80 ? "(?<=.{57})[A-Z](?=->)" : "(?<=.{39})[A-Z](?=->)";
        $text = SWISS::TextFunc->wrapOn($prefix,
            $prefix2,
            $SWISS::TextFunc::lineLength, $text,
            "$SWISS::TextFunc::textWrapPattern1",
            "/|:(?=[^}]+\\})|$SWISS::TextFunc::textWrapPattern2|$sep_seqchange_re"
        );
        # wrap on some ws or "-", then "/" or ":" inside evtags or some "-", then
        # before default split on any char after max size: if "-" in  XXX->YYY is at max pos, do wrap on previous AA
    }
    else { # wrapping for other FT lines
        $text = SWISS::TextFunc->wrapOn($prefix,
            $prefix2,
            $SWISS::TextFunc::lineLength, $text, "$SWISS::TextFunc::textWrapPattern1",
            "/|:(?=[^}]+\\})|$SWISS::TextFunc::textWrapPattern2"
        );
        # wrap on some ws or "-", then "/" or ":" inside evtags or some "-"
    };
    return $text;
}

#sorting based on annotation rule ANN027,
#and additional instructions from Amos.
#FTs should be sorted based on :
#-the priority index, or
#-the starting position (lesser goes first), or
#-the ending position (longer goes first), or
#-structured fields values (alphab. from alphab. sorted keys)
#-the FT comment as a last resort.
sub sort {
	my $self = shift;

	my $self_list = $self->list;

	my @indices = sort {
		my $item1 = ${$self_list}[$a];
		my $item2 = ${$self_list}[$b];

        ( my $fid1 = $item1->[6] || "" ) =~ s/^[^-]+-//; # formid e.g. from Q86TG7-2 => 2
        ( my $fid2 = $item2->[6] || "" ) =~ s/^[^-]+-//;

		my $sv =
            # sort by isoform name (empty=canonical first)
            ( $fid1 || 0 ) <=> ( $fid2 || 0 ) ||
			#sort by virtual key
			($KEYORDER{$item1->[0]} || 0) <=> ($KEYORDER{$item2->[0]} || 0) ||
			# or by start position
			_numericPosition($item1->[1], $item1->[2]) <=> _numericPosition($item2->[1], $item2->[2]) ||
			# or by end position (reversed)
			_numericPosition($item2->[2], $item2->[1]) <=> _numericPosition($item1->[2], $item1->[1]);
			# for FT VARSPLIC and VAR_SEQ:
			# as a penultimate resort, alphabetically on what follows the parenthesis in the FTcomment

        if (!$sv and $item1->[0] =~ /^VARSPLIC|VAR_SEQ$/
					and my ($t1) = $item1->[3] =~ /\((.*)/
					and my ($t2) = $item2->[3] =~ /\((.*)/
					) {
				$sv = lc($t1) cmp lc($t2) || $t1 cmp $t2;
			}

        # (if still "equal" / no preference:)
        # for FT CONFLICT+VARIANT: as a penultimate resort, alphabetically on FTcomment
        # (except "Missing" that should go at the end)
        unless ($sv) {
            if (grep {$_ eq $item1->[0]} ("CONFLICT", "VARIANT", "MUTAGEN")) {
                if ($item1->[3] =~ /^Missing/i) {
                    unless ($item2->[3] =~ /^Missing/i) {
                        $sv = 1;
                    }
                }
                else {
                    if ($item2->[3] =~ /^Missing/i) {
                        $sv = -1;
                    }
                }
            }
            else { # if there are structured fields: alphabetically on structured values (from alphab. sorted keys)!
                if ( keys( %{ $item1->[8] } ) ) {
                    my $s1 = join "\n", map { $_."\t".$item1->[8]->{$_} } ( sort { $a cmp $b } keys( %{ $item1->[8] } ) );
                    my $s2 = join "\n", map { $_."\t".$item2->[8]->{$_} } ( sort { $a cmp $b } keys( %{ $item2->[8] } ) );
                    $sv = lc($s1) cmp lc($s2) || $s1 cmp $s2;
                }
            }
        }
        # as a last resort, alphabetically on FTcomment (e.g. variants)
        $sv || lc($item1->[3]) cmp lc($item2->[3]) || $item1->[3] cmp $item2->[3]
    } 0..$#$self_list;
	my @newlist;
	for (@indices) {
		push @newlist, ${$self_list}[$_];
	}
	$self->list(\@newlist);
}

# For a given feature position, return the numeric position.
# This converts "fuzzy" positions for sorting purpose, according to the rule:
# 11 => 11
# >14 => 14.1
# <1 => 0.9
# ?31 => 31
# if a position is only "?", the other position should be passed as a second
# argument, to be used as a backup. For example, if a feature is
# FT   CHAIN         ?    103       Potential.
# the position 103 should be considered the best-guess start position for sorting.
sub _numericPosition {
	for my $string (@_) {
		return $1+0.1 if $string =~ />(\d+)/;
		return $1-0.1 if $string =~ /<(\d+)/;
		return $1 if $string =~ /(\d+)/;
	}
	return 0;
}

1;

=head1 Name

SWISS::FTs

=head1 Description

B<SWISS::FTs> represents the FT (feature) lines within an SWISS-PROT + TrEMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<list>

An array of arrays. Each element is an array containing: a feature key, from 
position, to position, description, qualifier, FTId, form-id, evidence tag, extra fields key-val hashmap reference.
Examples:
(>=2019.11 format:)(+2022_03)
[' MOD_RES', 3, 32, 'Phosphoserine', 'By similarity', 'PRO_0000089360', 'Q9ULC5-3', ' {ECO:0000244|PubMed:18691976}', { 'akey' => 'avalue' }]
(old format with old EBI-style ev:)
['CHAIN', 25, 126, 'Alpha chain', 'By similarity', '/FTId=PRO_0000023008', undef, '{EC1}', undef]

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=item sort

=back

=cut

__DATA__
INIT_MET SIGNAL PROPEP TRANSIT CHAIN PEPTIDE
TOPO_DOM TRANSMEM INTRAMEM
DOMAIN REPEAT
CA_BIND ZN_FING DNA_BIND NP_BIND
REGION
COILED
MOTIF
COMPBIAS
ACT_SITE
METAL
BINDING
SITE
NON_STD
MOD_RES
LIPID
CARBOHYD
DISULFID 
CROSSLNK
VAR_SEQ
VARIANT
MUTAGEN
UNSURE
CONFLICT
NON_CONS
NON_TER
HELIX TURN STRAND
