package SWISS::CCcopyright;

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
	     text => undef
	    );
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
  my $self = new SWISS::CCcopyright;
  my $text = $$textRef;
  $self->text($text);
  $self->{_dirty} = 0;
  return $self;
}

sub toString {
  my $self = shift;
  my $text = $self->text;
  $text =~ s/\A\-/CC   \-/g;
  
$text =~ s/-{74}/-----------------------------------------------------------------------/;
  # fix CC line punctuation issue (need full stop inside CC block, may be lost
  # in earlier processing of CC section)
  
  # 12/11/2007: this full stp is apparently no longer required
  
  # $text =~ s/(?<!\.)\nCC   \-/\.\nCC   -/;
  
  
  
  return $text . "\n";
}

sub topic {

  return "Copyright";
}

sub comment {

  my $self = shift;
  return $self -> text;
}

1;

__END__

=head1 Name

SWISS::CCcopyright

=head1 Description

B<SWISS::CCcopyright> represents the copyright statment within the comments
block of a SWISS-PROT entry as specified in the user manual
 http://www.expasy.org/sprot/userman.html .   Collectively, comments of all types
 are stored within a SWISS::CCs container object.

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item topic

    The topic of this comment ('Copyright').

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=back

=head2 Reading/Writing methods

=over

=item toString

    Returns a string representation of this comment.

=back
