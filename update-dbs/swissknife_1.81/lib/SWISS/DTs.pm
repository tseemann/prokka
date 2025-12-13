package SWISS::DTs;

use vars qw($AUTOLOAD @ISA @EXPORT_OK %fields @DATENAMES @RELNAMES %UPPER2MIXED);

use Exporter;
use Carp;
use strict;

use SWISS::TextFunc;
use SWISS::BaseClass;

BEGIN {
  @EXPORT_OK = qw();
  
  @ISA = ( 'Exporter', 'SWISS::BaseClass');
  
  %fields = (
    'CREATED_date' => undef,
    'ANN_date' => undef,
    'SQ_date' => undef,
    'CREATED_rel' => undef,
    'ANN_rel' => undef,
    'SQ_rel' => undef,
    'ANN_version' => undef,
    'SQ_version' => undef,
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

  my $self = new SWISS::DTs;
  my (@tmp, $date, $release, $version);

  if ($$textRef =~ /($SWISS::TextFunc::linePattern{'DT'})/m){
    @tmp = map{SWISS::TextFunc->cleanLine($_)} split /\n/m, $1;
    #new format
    if ($tmp[0] =~ /(\d{2}\-\w{3}\-\d{4}), integrated into (.+)\./i){
      $date = $1;
      $release = $2;
      $self->CREATED_date($date);
      $self->CREATED_rel($release);
    }
    #old format
    elsif ($tmp[0] =~ /(\d{2}\-\w{3}\-\d{4}) \(([^\,]+), Created\)/i){
      $date = $1;
      $release = $2;
      $self->CREATED_date($date);
      $self->CREATED_rel($release);
    }
    #new format
    if ($tmp[1] =~ /(\d{2}\-\w{3}\-\d{4}), sequence version (\d+)/i){
      $date = $1;
      $version = $2;
      $self->SQ_date($date);
      $self->SQ_version($version);
    }
    #old format
    elsif ($tmp[1] =~ /(\d{2}\-\w{3}\-\d{4}) \(([^\,]+), Last sequence update\)/i){
      $date = $1;
      $release = $2;
      $self->SQ_date($date);
      $self->SQ_rel($release);
    }
    #new format
    if ($tmp[2] =~ /(\d{2}\-\w{3}\-\d{4}), entry version (\d+)/i){
      $date = $1;
      $version = $2;
      $self->ANN_date($date);
      $self->ANN_version($version);
    }
    #old format
    elsif ($tmp[2] =~ /(\d{2}\-\w{3}\-\d{4}) \(([^\,]+), Last annotation update\)/i){
      $date = $1;
      $release = $2;
      $self->ANN_date($date);
      $self->ANN_rel($release);
    }
  };

  $self->{_dirty} = 0;
  
  return $self;
}

sub toText {
  my $self = shift;
  my $textRef = shift;

  my $newText;

  if (defined $self->ANN_version) {
    $newText = 
         'DT   ' . $self->CREATED_date . ', integrated into ' . $self->CREATED_rel . ".\n" .
         'DT   ' . $self->SQ_date . ', sequence version ' . $self->SQ_version . ".\n" .
         'DT   ' . $self->ANN_date . ', entry version ' . $self->ANN_version . ".\n";
  }
  else {
    $newText = join ('', 
         'DT   ', $self->CREATED_date, 
         " \(", $self->CREATED_rel, ", Created\)\n",
         'DT   ', $self->SQ_date, 
         " \(", $self->SQ_rel, ", Last sequence update\)\n",
         'DT   ', $self->ANN_date, 
         " \(", $self->ANN_rel, ", Last annotation update\)\n");
  }

  $self->{_dirty} = 0;

  return SWISS::TextFunc->insertLineGroup($textRef, $newText, 
					  $SWISS::TextFunc::linePattern{'DT'});
  
}

sub set_Created {
  my $self=shift;
  my ($date, $release) = @_;

  $self->CREATED_date($date);
  $self->CREATED_rel($release);
}

sub set_AnnotationUpdate {
  my $self=shift;
  my ($date, $release, $version) = @_;

  $self->ANN_date($date);
  $self->ANN_rel($release);
  $self->ANN_version($version) if defined $version;
}

sub set_SequenceUpdate {
  my $self=shift;
  my ($date, $release, $version) = @_;

  $self->SQ_date($date);
  $self->SQ_rel($release);
  $self->SQ_version($version) if defined $version;
}

1;

__END__

=head1 Name

SWISS::DTs

=head1 Description

B<SWISS::DTs> represents the DT lines within an Swiss-Prot + TrEMBL
entry as specified in the user manual
http://www.expasy.org/sprot/userman.html .

=head1 Inherits from

SWISS::BaseClass.pm

=head1 Attributes

=over

=item C<CREATED_date>

Creation date

=item C<ANN_date>

Last annotation update

=item C<SQ_date>

Last Sequence update

=item C<CREATED_rel>

Created for release

=item C<ANN_rel>

Last annotation for release

=item C<SQ_rel>

Last sequence update for release

=item C<ANN_version>

Version number for entry annotation

=item C<SQ_version>

Version number for sequence

=back

=head1 Methods

=head2 Standard methods

=over

=item new

=item fromText

=item toText

=item sort

=back

=head2 Writing methods

=over

=item set_Created ($date, $release)

=item set_AnnotationUpdate ($date, $release[, $version])

=item set_SequenceUpdate ($date, $release[, $version])

=back

=head1 TRANSITION

The format of the DT line will change in early 2004 from:

 DT   01-JUL-1993 (Rel. 26, Created)
 DT   01-JUL-1993 (Rel. 26, Last sequence update)
 DT   28-FEB-2003 (Rel. 41, Last annotation update)

to:

 DT   01-JUL-1993, integrated into UniProtKB/Swiss-Prot.
 DT   01-JUL-1993, sequence version 36.
 DT   28-FEB-2003, entry version 54.

This module supports both formats. To convert an entry from the old to
the new format, do:

 $entry->DTs->CREATED_rel("UniProtKB/Swiss-Prot");
 $entry->DTs->ANN_version(54);
 $entry->DTs->SQ_version(36);
