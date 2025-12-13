package SWISS::DE;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::BaseClass;


BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass');
  
  %fields = (
	     'text' => undef,
         'category' => undef, # (in new format) RecName | AltName
         'type' => undef, # ... Full | Short | EC | Allergen | CD_antigen
         
         'hide_in_old' => undef, # ... for CD_antigen already seen ouside CD_antigen (to be hidden in old format) 
	    );
}

sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::BaseClass;
  
  $self->rebless($class);
  
  $self->{category} = shift;
  $self->{type} = shift;
  
  return $self;
}

sub fromText {
  my $self = new(shift);

  my $text = shift;

  # Parse out the evidence tags
  if ($text =~ s/($SWISS::TextFunc::evidencePattern)//) {
    my $tmp = $1;
    $self->evidenceTags($tmp);
  }

  $self->text($text);

  $self->{_dirty} = 0;
  return $self;
}

sub toText {
  my $self = shift;
  my $addParen = shift;
  
  my $str = $self->text;

  if (my $type = $self->{type}) {
    # if defined = is new format: remove useless type txt inside name 
    # (!legacy from old format!)
    my $process_txt_by_type = {
    # transform stored name string (old format) into clean new names
        'Full'          => sub {
                            my $str = shift or return;
                            #$str =~ s/ precursor$//;
                            return $str;
                        },
        'EC'        =>  sub {
                            my $str = shift or return;
                            $str =~ /^EC (\d.+)/;
                            return $1;
                        },
        'Allergen'  =>  sub {
                            my $str = shift or return;
                            $str =~ /^Allergen (.+)/;
                            return $1;
                        },
        'CD_antigen'  =>  sub {
                            my $str = shift or return;
                            $str =~ /^(.+) antigen$/;
                            return $1;
                        }
    };
    # process str (only if new format is asked! as 
    # .... DEs->is_old_format(1) might be used to convert new format back 
    # to old format ...)
    $str = $process_txt_by_type->{$type}->($self->{text})
        if $process_txt_by_type->{$type} and !$self->{is_old_format};
      
  }
  return '' if $self->{is_old_format} && $self->{hide_in_old};
  return $addParen ? '(' . $str . ')' . $self->getEvidenceTagsString:
                           $str .       $self->getEvidenceTagsString;
}

1;

__END__

=head1 Name

SWISS::DE.pm

=head1 Description

Each DE object represents one protein name. The container object for all names 
of an entry is SWISS::DEs

=head1 Inherits from

SWISS::BaseClass

=head1 Attributes

=over

=item C<text>

The raw text of the protein name. 
Note: as SwissKnife works with both new and old DE line formats, for backward 
rcompatibility, with both formats everything is parsed and stored the same way as it 
was with the old format. Therefore the raw text for a name of type 'EC' e.g. 
6.3.5.5 will be "EC 6.3.5.5" (instead of "6.3.5.5"). Other strings only present 
in old DE line text format ('precursor' flag and 'Allergen', 'antigen' strings) 
are also added in the stored raw text.
The safe method to get the DE text is C<toText> (with both the new and old 
DE line format), which for "EC=6.3.5.5" (new DE line format), will return 
"6.3.5.5" (DE object of 'EC' type). For "(EC 6.3.5.5)" (old DE line format), 
will return "EC 6.3.5.5" 

=item C<category>

The category of the protein name: 'RecName', 'AltName', 'SubName' (TrEMBL only)

 DE   RecName: Full=CAD protein;
 DE            Short=CAD;
 
 Here both names (DE objects), are of category 'RecName'

Category can be set/modified using C<category(string)>

Note: with the old DE line format, this field is undef

=item C<type>

The type of the protein name: 'Full', 'Short', 'EC' 'Allergen', 'CD_antigen',
'Biotech','INN'

 DE   RecName: Full=CAD protein;
 DE            Short=CAD;
 
 Here the first name (DE object), is of type 'Full', the second one 
 is of type 'Short'

Type can be set/modified using C<type(string)>

Note: with the old DE line format, this field is undef


=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText ($addParen)

 addParen : (meaningful only with old DE line format) if set to true, 
 the name will be surrounded by parentheses, but not the evidence 
 tags, e.g. : '(UMP SYNTHASE){E1}'.

=back

=head1 Evidence Tags

Each protein name (DE object) can have independent evidence tags.

 DE   SubName: Full=Histone H3{EI1};
 DE            EC=3.4.21.9{EC3};
 DE   AltName: Full=Enterokinase{EC5};

The following methods have their prototype defined in 
SWISS::BaseClass instead of the direct parent of SWISS::DEs, SWISS::ListBase :

 addEvidenceTag
 deleteEvidenceTags
 getEvidenceTags
 getEvidenceTagsString
 hasEvidenceTag
 setEvidenceTags

example :

 $evidenceTag = $entry->Stars->EV->addEvidence('P', 'DEfix', '-', 'v1.3');
 $entry->DEs->head->addEvidenceTag($evidenceTag);
 
The easiest way to read the evidence tags of a protein name is to use 
c<getEvidenceTagsString> that will return the evidence tags as a string with 
the enclosing {} brackets. If there are no evidence tags, will return an empty 
string.
