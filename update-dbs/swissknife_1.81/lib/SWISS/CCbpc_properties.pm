package SWISS::CCbpc_properties;

use vars qw($AUTOLOAD @ISA @_properties %fields);

use Carp;
use strict;
use SWISS::TextFunc;
use SWISS::BaseClass;


BEGIN {
  @ISA = ('SWISS::BaseClass');

  @_properties = (
    ['Absorption', 'Abs(max)', 'Note'],
    ['Kinetic parameters', 'KM', 'Vmax', 'Note'],
    ['pH dependence'],
    ['Redox potential'],
    ['Temperature dependence'],
  ); # now each

  %fields = map {
      $_->[0], undef
  } @_properties;
}


sub new {
  my $ref = shift;
  my $class = ref($ref) || $ref;
  my $self = new SWISS::BaseClass;
  $self->rebless($class);
  return $self;
}


sub fromText {
    my $class = shift;
    my $textRef = shift;
    my $self = new SWISS::CCbpc_properties;

    my $text = $$textRef;
    $self->initialize();

    my $properties_re = join "|", map {$_->[0]} @_properties;

    $text =~ s/ {2,}/ /g;
    $text =~ s/\s*-!- BIOPHYSICOCHEMICAL PROPERTIES:\s*(?:\[(.+)\]:)?\s*//;
    $self->{form}=$1||"";

    my $last_property = $_properties[0][0]; #"default" property

    while (length $text) {
        if ($text =~ s/^\s*($properties_re):\s*(.*?)\s*(;\s*|\Z)//so) {
            my ( $property, $ltext ) = ( $1, $2 );
            $last_property = $property;
            my $keys_re = join "|", map { map { "\Q$_\E" } @$_[ 1..$#$_ ] } grep { $_->[0] eq $property } @_properties;
            my @content;

            if ( $ltext =~ s/^($keys_re)=// and length $ltext ) { # 1st "key" (sub property) in $1 e.g. Vmax
                @content = [$1, SWISS::CC::parse2Blocks( $ltext ) ];
                # n.b. a single key if not "Note" (e.g. Vmax) has (so far!) only one sentence - ev, but use parse2Blocks anyway! symmetrical with free text prop + in case it gets multi block!
                # n.b caution: in real free text multi block; sentences ends with " ." then ev, here there is no " ."!...
            }
            elsif (length $ltext) { # no key=, just free text (e.g for pH dependence)
                @content = [undef, SWISS::CC::parse2Blocks( $ltext ) ];
            }
            while ($text =~ s/^($keys_re)=(.*?)\s*(;\s*|\Z)//) { # other keys e.g. Note=, Vmax=, ...
                my ($field, $txt) = ($1, $2);
                next unless length $txt;
                push @content, [ $field, SWISS::CC::parse2Blocks( $txt ) ];
            }
            $self->{$property} = \@content;
        }
        else { # dangling text
            my ($ltext) = $text =~ s/(.*?)\s*(;\s*|\Z)//;
            push @{$self->{$last_property}}, [ undef, SWISS::CC::parse2Blocks( $ltext ) ];
        }
    }
    $self->sort;
    $self->{_dirty} = 0;
    return $self;
}


sub sort {
    my ($self) = @_;
    if ($self) {
        for my $property (@_properties) {
            my ($_property_name, @fields) = @$property;
            next unless @fields;
            my $fields = join " ", " ", @fields, " ";
            if (defined (my $val = $self->{$property->[0]})) {
                @$val = sort {index($fields, $a->[0] || "") <=> index($fields, $b->[0] || "") } @$val;
            }
        }
    }
}


sub toString {
    my $self = shift;

    my $form = $self->{ form };
    my $text = "-!- BIOPHYSICOCHEMICAL PROPERTIES:";
    $text .= ' ['. $form . ']:' if $form;
    $text .= "\n".$self->comment;
    $text =~ s/^/CC       /mg;
    $text =~ s/    //;

    return $text;
}


sub topic {
    return "BIOPHYSICOCHEMICAL PROPERTIES";
}


sub properties {
    my ($self) = @_;
    my @list;
    for my $property (@_properties) {
        next unless defined $self->{$property->[0]};
        push @list, $property->[0];
    }
    return @list;
}


sub fields {
    my ($self, $property) = @_;
    defined $property or confess "Must pass a property";
    my @list;
    if (defined (my $val = $self->{$property})) {
        for my $item (@$val) {
            push @list, $item;
        }
    }
    return @list;
}


sub comment {
    my ($self) = @_;
    my $text = "";
    if ($self) {
        for my $property (@_properties) {
            if (defined (my $val = $self->{$property->[0]})) {
                $text .= "$property->[0]:\n";
                for my $item (@$val) {
                  my ( $field, $blocks ) = @$item;
                  my $termin = !defined( $field ) || $field eq "Note" ? "." : "";
                  my $value = SWISS::CC::blocks2String( $blocks, "", $termin );
                  my $field_text = defined $field ? "$field=" : "";
                  my $t = "$field_text$value;";
                  $text .= SWISS::TextFunc->wrapOn('  ','  ', $SWISS::TextFunc::lineLength-9, $t);
                }
            }
        }
    }
  $text;
}

sub form {
    my $self = shift;
    return $self->{ form };
}

1;

__END__

=head1 Name

SWISS::CCbpc_properties.pm

=head1 Description

B<SWISS::CCbpc_properties> represents a comment on the topic 'BIOPHYSICOCHEMICAL PROPERTIES'
within a Swiss-Prot or TrEMBL entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .  Comments on other topics are stored
in other types of objects, such as SWISS::CC (see SWISS::CCs for more information).

Collectively, comments of all types are stored within a SWISS::CCs container
object.

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item topic

The topic of this comment ('BIOPHYSICOCHEMICAL PROPERTIES').

=item form

The protein form concerned by this comment (undef/empty = canonical/displayed form OR unknown

=item properties

A list of all filled properties in this comment.

=item fields($properties)

A list of "records" for a given property (e.g. "Absorption") in this comment.
Each "record" is a reference to an array of [$field_name, [[$sentence, $evidence_tags]] ].
$field is undefined for unnamed fields.

=back
=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toString

Returns a string representation of this comment.

=back
