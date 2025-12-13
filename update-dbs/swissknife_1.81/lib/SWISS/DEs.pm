package SWISS::DEs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::ListBase;
use SWISS::DE;

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::ListBase');
  
  %fields = ('text' => undef,
             'hasFragment' => undef,
             'isPrecursor' => undef,
             'version' => undef,
             'Contains' => undef,
             'Includes' => undef,
             'is_old_format' => undef,
            );
}

sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::ListBase;
  $self->rebless($class);
  $self->Contains (new SWISS::ListBase);
  $self->Includes (new SWISS::ListBase);
  $self->{is_old_format} = 0;# now the default is new format
  return $self;
}

sub fromText {
  my $class = shift;
  my $textRef = shift;
  my $self = new SWISS::DEs;

  my $line = '';
  my $evidence = '';
 
  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'DE'})/m) {
    $line = $1;  
    $self->{indentation} = $line =~ s/^ //mg;
    
    # if not new DE format
    unless($line =~ / RecName:| AltName:| SubName:| Flags:/) {
        # is old format
        $self->{is_old_format} = 1;
        $line = SWISS::TextFunc->joinWith('', ' ', '(?<! )-', 'and ',
                                          map {SWISS::TextFunc->cleanLine($_)}
                                              (split "\n", $line));
        # Drop trailing spaces and dots
        $line =~ s/[\. ]*$//;
    }
    else {
        $self->{is_old_format} = 0;
    }

  };
  if ($self->{is_old_format}) {
  # Parse for evidence tags
      if (($evidence) = $line =~ /($SWISS::TextFunc::evidencePattern)/m) {
        $line =~ s/$evidence//m;
        $self->evidenceTags($evidence);
      }
  }

  $self->{text} = $line;
  $self->{is_old_format} = 1 unless $line;
  $self->advancedParse();

  $self->{_dirty} = 0;
  
  return $self;
}

sub fromString {
  my $class = shift;
  my $string = shift;
  my $is_old_format = shift;
  my $self = new SWISS::DEs;
  $self->{text} = $string;
  $self->{is_old_format} = $is_old_format;
  $self->advancedParse;
  $self->{_dirty} = 0;
  return $self;
} 

sub text {
  my $self = shift;
  my $text = shift;
  if ($text) {
    $self->{_dirty} = 1;
    $self->{text} = $text;
    $self->{is_old_format} = 
        ($text =~ /RecName:|AltName:|SubName:|Flags:/ ? 0 : 1);
    $self->advancedParse;
  }
  else {
    $text = $self->toString();
  }
  return $text;
}

sub to_old_format {
    my $self = shift; 
    $self->{is_old_format} = 1;
    $self->{_dirty} = 1;
    
    # stupid: in old format we want EC before short, in new they are after
    sub move_back_ec {
        my $de = shift or return;
        my $j=0;
        for (my $i=0;$i<scalar(@$de);$i++) {
            $de->[$i]->{is_old_format} = 1;
            if ($de->[$i]->{type} eq 'Short') {
                $j++;
            }
            elsif ($de->[$i]->{type} eq 'EC' && $j) {
                my $tmp = $de->[$i];
                for (my $k=0;$k<$j;$k++) {
                    next if $i-$k <2;
                    $de->[$i-$k] = $de->[$i-$k-1]
                }
                $de->[$i-$j] = $tmp;# put EC at beginning
            }
            else {
                $j=0;
            }
        }        
    }
    
    if ($self->isPrecursor) {
        my $txt = $self->head->text;
        $self->head->text($txt . ' precursor') unless $txt =~ /precursor$/i;
    }
    foreach my $de ($self->{list}) {
        move_back_ec($de);
    }
    foreach my $dess ($self->Contains->{list}) {
        foreach my $des (@$dess) {
            foreach my $de ($des->{list}) {
                move_back_ec($de);
            }
        }
    }
    foreach my $dess ($self->Includes->{list}) {
        foreach my $des (@$dess) {
            foreach my $de ($des->{list}) {
                move_back_ec($de);
            }
        }
    }
    
    # FIXME: evtags (are flag evt!) remove them?
}

sub advancedParse {
  my $self = shift;
  # if is new format
  return $self->advancedParseNew() unless $self->{is_old_format};
  
  # parse old format
  
  my $t = $self->{text};     
  $self->initialize;
  my($hasFragment, $version);
                                                              
  #1)version
  if ($t =~ s/\s*\((Version \S+)\)//i) {
    $version = $1;
  }
  $self->version($version);
   
  #2)fragment                                                              
  if ($t =~ s/\s*\((Fragments?)\)//i) {
    $hasFragment = $1;
  }
  $self->hasFragment($hasFragment);
   
  #3)children
  $self->Contains->set();
  $self->Includes->set();

  #protect internal [] by converting to {- -}
  1 while $t =~  s/(\[[^\[\]]*)\[(.*?)\]/$1\{-$2-\}/;
  #parse Contains/Includes
  while ($t =~ s/\s*\[((?:Contains)|(?:Includes)):\s*(.*?)\]//i) {  
    my $type = lc $1 eq "contains" ? $self->Contains : $self->Includes;
    $type->push(
        map {
            s/\{-/[/g; s/-\}/]/g;
            SWISS::DEs->fromString($_,1);
        } split /;\s*/, $2);
  }
  # convert protected brackets back to original form
  $t =~ s/\{-/[/g; $t =~ s/-\}/]/g;

  #4)list
  #protect internal () by converting to {- -}
  1 while $t =~  s/(\([^\(\)]*)\((.*?)\)/$1\{-$2-\}/;
  #must reverse before parsing to match successively all exprs between ()
  $t = reverse $t;
  my $ev = $SWISS::TextFunc::evidencePatternReversed;
  while ($t =~  s/^($ev)?\)(.*?)\(\s+//) {
    my $a = $3; #$2 is set by the evidence pattern
    $a = $1.$a if $1; #evidence tag
    $a =~ s/-\{/\(/g;
    $a =~ s/\}-/\)/g;
    $self->unshift(SWISS::DE->fromText(scalar reverse $a));
  }
  # convert protected brackets back to original form, 
  # then add remaining text
  $t =~ s/-\{/\(/g;
  $t =~ s/\}-/\)/g;
  $self->unshift(SWISS::DE->fromText(scalar reverse $t));
    # note: even if {text} is empty (no DE line) there will be a DE obj
    # so head method will work
}


sub advancedParseNew {
# advance parsing for new format
# Note: the new format is saved into the old simple structure !...
# Code will work ~ the same with both format.
# Adding a DE in the new format will just require specifying 
# category (RecName, AltName, SubName) and type (Full, Short, EC, Allergen, 
# CD_antigen) in DE stored in DEs
    my $self = shift;
  
    $self->Contains->set();
    $self->Includes->set();
  
    $self->initialize;
    
    my $by_mode = {# dispatch table to save new data into old structure
       'Main' => sub {  
                        my ($str,$is_new_list,$cat,$type,$hide_in_old,$n) = @_;
                        my $de = SWISS::DE->fromText($str);
                        $de->category($cat);
                        $de->type($type);
                        $de->hide_in_old($hide_in_old);
                        $de->{ _grp_n } = $n;                         
                        $self->push($de);
                    },
       'Contains' => sub {   
                        my ($str,$is_new_list,$cat,$type,$hide_in_old,$n) = @_;
                        my $obj = $self->Contains;
                        if ($is_new_list) {
                        # is new contains: create new DEs to add names
                            my $contains = new SWISS::DEs;
                            $obj->push($contains);
                        }
                        # add DE (from str) to DEs(listbase)
                        my $de = SWISS::DE->fromText($str);
                        $de->category($cat);
                        $de->type($type);
                        $de->hide_in_old($hide_in_old);
                        $de->{ _grp_n } = $n;                        
                        $obj->item(-1)->push($de);
                    },
       'Includes' => sub{
                        my ($str,$is_new_list,$cat,$type,$hide_in_old,$n) = @_;
                        my $obj = $self->Includes;
                        if ($is_new_list) {
                            my $inludes = new SWISS::DEs;
                            $obj->push($inludes);
                        }
                        my $de = SWISS::DE->fromText($str);
                        $de->category($cat);
                        $de->type($type);
                        $de->hide_in_old($hide_in_old); 
                        $de->{ _grp_n } = $n; 
                        $obj->item(-1)->push($de);
                    }
    };
    
    my $process_txt_by_type = {
    # transform name string into the old format (so that new format could be 
    # converted into old one, if needed [transitory period])
        'EC'        =>  sub {
                            my $str = shift or return;
                            return "EC $str";
                        },
        'Allergen'  =>  sub {
                            my $str = shift or return;
                            return "Allergen $str";
                        },
        'CD_antigen'  =>  sub {
                            my $str = shift or return;
                            return "$str antigen";
                        }
    };

    my $raw = $self->{text};
    my $mode = 'Main';
    my $is_new_list;
    my $cat = '';
    my @flags;
    my $cd_antigen_outside = {};

    my $grp_n = 0;
    foreach my $line (map {s/^DE   //;$_} split '\r?\n',$raw) {
        if ($line =~ /^(Contains|Includes)/) {# Contains: | Includes:
            $mode = $1;
            $is_new_list = 1;
            next;
        }
        if ($line =~ /^Flags:\s+(.+)/) {# flags (Precursor, Fragment, Fragments)
            my $flags = $1;
            @flags = map {
                if (/($SWISS::TextFunc::evidencePattern)/m) {
                # store flag evtag as evtag for DEs self obj itself! (hack)
                    my $ev = $1;
                    $self->addEvidenceTag($ev);
                    s/\Q$ev//;# strip evtag
                }
                # store hasFragment
                if (/(Fragments?)/) {
                    $self->hasFragment(my $flag = $1);# !($1) doesn't work
                }
                # store isPrecursor
                $self->{isPrecursor} = 1 if /^precursor/i;
                
                $_;
            } sort {$b cmp $a} split '; *', $flags;
            next;
        }

        if ( $line =~ s/^ *(\w+): *// 
                and !( $cat eq 'RecName' && $cat eq $1 ) ) {
            $cat = $1 ;# category: RecName: | AltName:
            $grp_n++;
                # increment group counter. ... to help distinguish grps;
                # generaly useless! (as grps can be detected by a change in cat
                # or type ne 'Short' nor 'EC' and as DEs built with SK won't
                # have this field set) except when parsing an existing entry DE 
                # with Full missing from a Short / EC grp (curation error)...
                # (but do not inc grp if >1 RecName in a row...)
        }
        my ( $type, $val ) = split /= */, $line, 2;
        $type =~ s/\s+//g;# type: Full | Short | EC | Allergen | CD_antigen
        $val  =~ s/;\s*$//g;# value: name/descriptor
        $cd_antigen_outside->{$1} = 1
            if $type ne 'CD_antigen' && $val =~ /^(CDw?\d+) antigen/;
        my $hide_in_old = 
            $type eq 'CD_antigen' && $cd_antigen_outside->{ $val } ?
                1 : 0;
        # put data into old structure, so that new format could be converted 
        # into old one!! (therefore structure of new format can only be deduced
        # by analazing category and type fields of elements in a simple list!)
        $val = $process_txt_by_type->{ $type }->( $val ) 
            if $process_txt_by_type->{ $type };
        $by_mode->{ $mode }
                ->( $val,$is_new_list,$cat,$type, $hide_in_old, $grp_n ) 
            if $by_mode->{ $mode };
        
        $is_new_list = 0;
    }

}


sub toString {
  my $self = shift;

  # if is new format
  return $self->toStringNew() unless $self->{is_old_format};

  # rebuild old format
  
  my $newText = '';
  
  if ($self->size > 0) {# Main names
    map {$_->{is_old_format} = 1} $self->elements;
    $newText = join(' ', $self->head->toText, 
                    grep {$_} map {$_->toText(1)} $self->tail);
  }
  # Includes/Contains
  for my $p (["Includes", $self->Includes], ["Contains", $self->Contains]) {
    my ($type, $obj) = @$p;
    next unless $obj->size;
    $newText .= ' ' if $newText;
    my $text = join '; ', grep {$_} 
            map {$_->{is_old_format} = 1;            
            $_->toString} $obj->elements;
    $newText .= "[$type: $text]";
  }
  for ($self->hasFragment, $self->version) {
    next unless $_;
    $newText .= ' ' if $newText;
    $newText .= '(' . $_ . ')';
  }
  return $newText;
}


sub toStringNew {
  my $self = shift;
 
    my $str_out = '';
    my @flags;

    my $process_txt_by_type = {
    # transform stored name string (always old format! except Full, like old txt
    # but without 'precursor' at the end) into clean new names
        'Full'          => sub {
                            my $str = shift or return;
                            my $i = shift;# position 
                            #push @flags, 'Precursor' 
                            #    if defined($i) && !$i 
                            #        && $str =~ s/ precursor$//;
                            return $str;
                        },
        'EC'        =>  sub {
                            my $str = shift or return;
                            $str =~ /^EC (\d.*)/;
                            return $1;
                        },
        'Allergen'  =>  sub {
                            my $str = shift or return;
                            $str =~ /^Allergen (.*)/;
                            return $1;
                        },
        'CD_antigen'  =>  sub {
                            my $str = shift or return;
                            $str =~ /^(.+) antigen$/;
                            return $1;
                        }
    };
    
    my $main = new SWISS::DEs;
    # build main, includes, contains
    foreach my $d (
        [ '' , ( $main->push($self) and $main ) ],
        [ 'Includes', $self->Includes ],
        [ 'Contains', $self->Contains ]) {
            
        my ($mode, $obj) = @$d;
        next unless $obj->size;

        my $indent = $mode ? '  ' : '';

        foreach my $grp ( $obj->elements ) {
            $str_out      .= "$mode:\n" if $mode;
            my $last_cat   = '';
            my $last_grp_n = 0;
            my $i          = 0;
            foreach my $de ($grp->elements) {
                my $txt   = $de->text() or next;
                my $ev    = $de->getEvidenceTagsString() || '';
                my $cat   = $de->category() || ($i ? '???????' : 'RecName');
                my $type  = $de->type() || ($i ? '????' : 'Full');
                my $grp_n = $de->{ _grp_n };
                $str_out .= 
                    (   ($type ne 'Short' && $type ne 'EC') 
                        || $cat ne $last_cat 
                        || ( $grp_n && $grp_n != $last_grp_n )
                        ? "$indent$cat: " : "$indent         " ); 
                        
                $txt = $process_txt_by_type->{ $type }->( $txt, $i )
                    if $process_txt_by_type->{ $type };
                $str_out   .= "$type=$txt$ev;\n";
                $i ++;
                $last_cat   = $cat;
                $last_grp_n = $grp_n;
            }
        }

    }
    # build flags
    push @flags, "Precursor" if $self->isPrecursor;
    push @flags, $self->hasFragment if $self->hasFragment;
    # add flag evtag (stored as DEs self evtags!
    if (my @flag_evtag = $self->getEvidenceTags()) {
        my $i = 0;
        @flags = map {
                my $ev = $flag_evtag[$i++] || '';
                $ev = "{$ev}" if $ev;
                $_.$ev;
            } @flags;
    }
    
    $str_out .= 'Flags: '.join('; ',@flags).";\n" if @flags;
    chomp $str_out;

    return $str_out;

}


sub toText {
  my $self = shift;
  my $textRef = shift;

  unless ($self->{_dirty}) {
    return;
  }

    unless ($self->{is_old_format}) {
    # new format
        my $out_str = '';
        my $prefix = "DE   ";$prefix=' '.$prefix if $self->{indentation};
        # FIXME: evtag in new format?
        foreach my $line (split '\r?\n',$self->toString) {
            $out_str .= $prefix.$line."\n";
        }
        $self->{_dirty} = 0;
        return SWISS::TextFunc->insertLineGroup($textRef, $out_str, 
                                          $SWISS::TextFunc::linePattern{'DE'});
    }
    
    
  my $newText = $self->toString . $self->getEvidenceTagsString;
  $newText .= "." if $newText;
  my $prefix = "DE   ";
  my $col = $SWISS::TextFunc::lineLength;
  $col++, $prefix=" $prefix" if $self->{indentation};
  $newText = SWISS::TextFunc->wrapOn($prefix, $prefix, $col, $newText);
  $self->{_dirty} = 0;
  
  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
                                          $SWISS::TextFunc::linePattern{'DE'});

};

sub sort {# sort DE elements
# - within "groups" sort Full first then Short, then EC (if any)
# - within same types (Full, Short, EC) (within a grp), sort alphabetically
# - sort AltName grps alphabetically by their Full (SDU-1000)
# - for Allergen, Biotech, CD_antigen, INN AltNames grps; put them at the end:
#   Allergen first, then Biotech, CD_antigen, INN
# - within multiple occurances of allergen, Biotech, CD_antigen, INN: sort
#   alphabetically
#
# (SDU-810) + new 'rule' with SDU-1000
#
# n.b. "group": names listed after distinct Rec/SubName|AltName: 
#      (e.g. Full,Short,EC under the same Rec/SubName|AltName)
#      (Allergen, Biotech, CD_antigen, INN each represent distinct groups)
#
# n.b. does not sort old DE format (<=2008)
    
    my $self = shift;
    return if $self->{ is_old_format }; # only sort DEs in new format!
    $self->{ _dirty } = 1;
    
    my $order = {
    # order for normal (non Allergen, Biotech, CD_antigen, INN)
    # name "groups"
        'Full'=> 1,
        'Short'=> 2,
        'EC'=> 3,
    };
    
    my $sort_des = sub {        

        my $des = shift or return;# array ref to list of DE

        # first sort/fix Full/Short/EC position within groups
        # (so that Full is always first)
        foreach my $de ( @$des ) {
            my $type = $de->type;
            # (sub field order: Full, Short then EC, inside multiple Short/EC: 
            #  sort alphabetically)
            $de->{ __a } = $de->{ _grp_n } . ( $order->{ $type } || '?' ) . 
                                $de->text;
        }
        @$des = sort { $a->{ __a } cmp $b->{ __a }; } @$des;
        
        # sort (normal) AltName "grp" by their full, 
        # put Allergen, Biotech, CD_antigen, INN at the end...
        # Rec|SubName at the beginning
        my $base_name  = '';
        my $last_grp_n = 0;
        foreach my $de (@$des) {
            my $cat   = $de->category;
            my $type  = $de->type;
            my $grp_n = $de->{ _grp_n };
            if ( $cat eq 'RecName' or $cat eq 'SubName' ) {
            # Rec|SubName stay at the beginning
                $de->{ __a }  = ' ' . $cat; 
            } elsif ( $order->{ $type } ) {
            # (normal) AltName "grp"
                $base_name = $de->text 
                    if  ( $grp_n && $grp_n != $last_grp_n )
                        || ( !$grp_n && $type eq 'Full' );
                    # memorize Full (1st) name of the "grp" to sort on it...
                    # (nb. use first name in group, if Full is missing
                    #  will use first available name!)
                    # if no DE has no _grp_n (not created by parsing an entry)
                    # use Full field...
                $de->{ __a }  = $base_name;# will be case insensitive sort
            } else {
            # (AltName) Allergen, Biotech, CD_antigen, INN stay at the end
            # (also use type + text so that multiple instances of the same type
            #  will be sorted alphabetically)
                $de->{ __a } = '~' . $type . $de->text;
            }
            $last_grp_n = $grp_n;
        }
        @$des = sort { $a->{ __a } cmp $b->{ __a }; } @$des;
        
    };
    
    # sort main names
    $sort_des->( $self->{ list } );
    # sort contains names
    foreach my $desl ( $self->Contains->{ list } ) {
        foreach my $des ( @$desl ) {
            $sort_des->( $des->{ list } );
        }
    }
    # sort includes names
    foreach my $desl ( $self->Includes->{ list } ) {
        foreach my $des ( @$desl ) {
            $sort_des->( $des->{ list } );
        }
    }
    
    return 1;
}


# for old DE format
# methods acting on evidence tag can be applied either to the entire DE line
# (pass a string) or to each element (passing an ARRAY reference).
# with new DE format: used to store Flags ev tag!, DE element ev tag are stored
# in corresponding DE object itself

sub addEvidenceTag { return ref $_[1] eq 'ARRAY' ? 
	 SWISS::ListBase::addEvidenceTag (@_) :
	SWISS::BaseClass::addEvidenceTag (@_)
}
sub deleteEvidenceTags { return ref $_[1] eq 'ARRAY' ? 
	 SWISS::ListBase::deleteEvidenceTags  (@_) :
	SWISS::BaseClass::deleteEvidenceTags  (@_)
}
sub getEvidenceTags { return ref $_[1] eq 'ARRAY' ? 
	 SWISS::ListBase::getEvidenceTags  (@_) :
	SWISS::BaseClass::getEvidenceTags  (@_)
}
sub getEvidenceTagsString { return ref $_[1] eq 'ARRAY' ? 
	 SWISS::ListBase::getEvidenceTagsString  (@_) :
	SWISS::BaseClass::getEvidenceTagsString  (@_)
}
sub hasEvidenceTag { return ref $_[1] eq 'ARRAY' ? 
	 SWISS::ListBase::hasEvidenceTag  (@_) :
	SWISS::BaseClass::hasEvidenceTag  (@_)
}
sub setEvidenceTags { return ref $_[1] eq 'ARRAY' ? 
	 SWISS::ListBase::setEvidenceTags  (@_) :
	SWISS::BaseClass::setEvidenceTags  (@_)
}

1;

__END__

=head1 Name

SWISS::DEs.pm

=head1 Description

B<SWISS::DEs> represents the DE lines of a UniProt Knowledgebase (Swiss-Prot 
+ TrEMBL) entry as specified in the user manual
http://www.expasy.org/sprot/userman.html.

The DEs object basically holds lists of DE objects, each of them representing a 
protein name element.
The C<elements>, C<hasFragment>, C<Includes> and C<Contains> attributes/methods 
work as follows :

 DE   RecName: Full=CAD protein;
 DE            Short=CAD;
 DE   AltName: Full=Protein rudimentary;
 DE   Includes:
 DE     RecName: Full=Glutamine-dependent carbamoyl-phosphate synthase;
 DE              EC=6.3.5.5;
 DE   Includes:
 DE     RecName: Full=Aspartate carbamoyltransferase;
 DE              EC=2.1.3.2;
 DE   Flags: Fragment;

 -= Entry::DEs =-
 elements (for each DE object, see SWISS::DE.pm documentation) :
    toText:    "CAD protein",  "CAD",       "Protein rudimentary"
    category:  "RecName",      "RecName",   "AltName"
    type:      "Full",         "Short"      "Full"    
 hasFragment : "Fragment"
 Includes : ListBase of DEs (child1, child2)
 Contains : empty ListBase

 -= child1 =-    
 elements (for each DE object) :
    toText:    "Glutamine-dependent carbamoyl-
                phosphate synthase",            "6.3.5.5"
    category:  "RecName",                       "RecName",
    type:      "Full",                          "EC"   
 hasFragment : undef

 -= child2 =-    
 elements (for each DE object) :
    toText:    "Aspartate carbamoyltransferase",  "2.1.3.2"
    category:  "RecName",                         "RecName",
    type:      "Full",                            "EC"  
 hasFragment : undef

Note: the old unstructured DE format can still be used, and will be parsed the 
same way into DE objects (but without setting their attributes 'category' and 
'type'.

 DE   CAD protein (Protein rudimentary) [Includes: Glutamine-dependent
 DE   carbamoyl-phosphate synthase (EC 6.3.5.5); Aspartate
 DE   carbamoyltransferase (EC 2.1.3.2)] (Fragment). 

 

=head1 Inherits from

SWISS::ListBase.pm

=head1 Attributes

=over

=item C<text>

The (raw) text of the DE line (without the 'DE   ' line type prefixes)

=item C<list>

Array reference to the SWISS::DE objects containing the different names for 
the entry. The first element of the list is the recommended name.
Note: use C<elements> method (inherited from ListBase) to get (and loop through)
the array of DE objetcs.

=item C<Includes>

=item C<Contains>

Each of these is a SWISS::ListBase object whose list contains a
SWISS::DEs object for each 'child' of the protein (i.e. peptide or functional
domain). See the UniProtKB user manual for an explanation. It is possible
to have both Includes and Contains in a single entry:

 DE   RecName: Full=Arginine biosynthesis bifunctional protein argJ;
 DE   Includes:
 DE     RecName: Full=Glutamate N-acetyltransferase;
 DE              EC=2.3.1.35;
 DE     AltName: Full=Ornithine acetyltransferase;
 DE              Short=OATase;
 DE     AltName: Full=Ornithine transacetylase;
 DE   Includes:
 DE     RecName: Full=Amino-acid acetyltransferase;
 DE              EC=2.3.1.1;
 DE     AltName: Full=N-acetylglutamate synthase;
 DE              Short=AGS;
 DE     RecName: Full=Arginine biosynthesis bifunctional protein argJ alpha chain;
 DE   Contains:
 DE     RecName: Full=Arginine biosynthesis bifunctional protein argJ beta chain;

=item C<hasFragment>

Contains 'Fragment' or 'Fragments' (evaluates to true) if the DE lines contain 
the 'Fragment(s)' indication (in 'Flags:' line with the new DE line format), 
otherwise evaluates to false. Compare to the more robust Entry::isFragment 
which also checks the FT lines for a NON_CONS or NON_TER.

=item C<isPrecursor>

Returns 1 if the flag 'Precursor' is present (undef if not). Note: only with new
DE line format.

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head1 Evidence Tags

With the new DE line format, each DE element can have distinct evidence tags, 
which are stored in the DE object themself (see SWISS::DE.pm documentation). 
The evidence tags for the 'Flags' line are stored in the parent DEs object 
itself.
With the old DE line format, since the DE line did not have a fixed syntax in 
TrEMBL, it is impossible to reliably assign evidence tags separately to the 
different elements of the DE lines. Therefore, the DE line can only be evidence 
tagged as a whole, and the following methods have their prototype defined in 
SWISS::BaseClass instead of the direct parent of SWISS::DEs, SWISS::ListBase :

 addEvidenceTag
 deleteEvidenceTags
 getEvidenceTags
 getEvidenceTagsString
 hasEvidenceTag
 setEvidenceTags

example :

 $evidenceTag = $entry->Stars->EV->addEvidence('P', 'DEfix', '-', 'v1.3');
 # add global DE evtag if old DE line format, 'Flags' evtag if new format
 $entry -> DEs -> addEvidenceTag($evidenceTag); 
