#!/usr/bin/perl

# The MIT License (MIT)

# Copyright (c) 2015 Dylan Storey

#  Permission is hereby granted, free of charge, to any person obtaining a 
#  copy of this software and associated documentation files (the "Software"), 
#  to deal in the Software without restriction, including without limitation 
#  the rights to use, copy, modify, merge, publish, distribute, sublicense, 
#  and/or sell copies of the Software, and to permit persons to whom the 
#  Software is furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in 
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
#  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
#  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
#  DEALINGS IN THE SOFTWARE.



use warnings;
use strict;
use Getopt::Long;

#time
my @abbr = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
my($day, $month, $year)=(localtime)[3,4,5];
my $DAY = join('-',($day, $abbr[$month],$year+1900));





#accepting full paths
my $comment = "Annotated using prokka from http://www.vicbioinformatics.com.";
my $faa = "PROKKA_08102014.faa";
my $fsa = "PROKKA_08102014.fsa";
my $tbl = "PROKKA_08102014.tbl";

GetOptions(
	"faa=s" => \$faa,
	"fsa=s" => \$fsa,
	"tbl=s" => \$tbl,
	"comment=s" => \$comment,
	) || usage();


my $global = {};
my $contigs = {};
my $features = {};

my $EOL = $/;

parse_fsa($fsa);
print STDERR "tbl2gbk: fsa is in!\n";
parse_faa($faa);
print STDERR "tbl2gbk: faa is in!\n";
parse_tbl($tbl);

exit;


sub parse_faa {
	open (IN , '<', shift) || die $!;
	local $/ = "\n>";
	my @records = <IN>;
	close IN;
	map {chomp}@records;

	map {
		my $record = $_;
		if ($record){
			my ($header , $seq) = split(/\n/ , $record,2); 
			die ($record) unless $seq;
			$seq =~s/[\n|\*]//g;
			$header=~s/>//g;
			my $feature = (split (/\s/,$header))[0];
			$features->{$feature} = $seq;
			}
		} @records;
	
	return;
	}


sub parse_fsa {
	open (IN , '<' , shift) || die $!;
	local $/ = "\n>";
	my @records = <IN>;
	close IN;
	map {chomp}@records;

	map {
		my $record = $_;
		if ($record){
			my ($header , $seq) = split(/\n/ , $record,2); 
			$seq =~s/\n//g;
			$seq =~s/\s//g;
			my $contig = $1 if $header =~/.*\|.*\|(.*_contig\d+)\s/;
			$contigs->{$contig}->{sequence} = $seq;
			$contigs->{$contig}->{length} = length $seq;
			unless (defined $global->{gcode} && defined $global->{organism} && defined $global->{strain}  ){
				$global->{gcode}    = $1 if $header =~ /gcode=(\d+)/;
				$global->{organism} = $1 if $header =~/\[organism=([^\]]*)/;
				$global->{strain}   = $1 if $header =~/\[strain=([^\]]*)/;
				}
		}
	}@records;	
	return;
	}

sub parse_tbl {
	open (IN , '<', shift) || die $!;
	local $/ = "\n>";
	my @CONTIGS = <IN>;
	map {chomp} @CONTIGS;
	close IN;

	map{
		my @features = split (/\n(?=\d)/,$_);
		my $header = shift @features;
		my $contig = $1 if $header =~/.*\|*\|(.*_contig\d+)/;
		die unless $contig;

		printf("%-12s%-15s%13s %s%4s%-8s%-8s %3s %-s\n",
                                  'LOCUS', $contig, $contigs->{$contig}->{length},
                                  ('bp',' ','DNA', 'linear'),' ', $DAY);

		_write_chunk("DEFINITION",12,"$global->{organism} strain $global->{strain}",80);
		_write_chunk("ACCESSION",12,'',80);
		_write_chunk("VERSION",12,'',80);
		_write_chunk("KEYWORDS",12,'',80);
		_write_chunk("SOURCE",12, $global->{organism},80);
		_write_chunk("ORGANISM",12,"$global->{organism} Unclassified",80);
		_write_chunk("COMMENT",12,$comment,80);
		_write_chunk("FEATURES",21,"Location/Qualifiers",80);
		_write_chunk("     source",21,"1..$contigs->{$contig}->{length}",80);
		_write_chunk("",21,"/organism=\"$global->{organism}\"",80);
		_write_chunk("",21,"/mol_type=\"genomic DNA\"",80);
		_write_chunk("",21,"/strain=\"$global->{strain}\"",80);

		map{
			my @information = split (/\n/,$_);
			my ($start,$stop,$type) = split(/\s+/,$information[0]);
			shift @information;
			my $location = ($start < $stop)? "$start..$stop" : "complement($stop..$start)";
			_write_chunk("     $type",21,$location,80);
			map{
				$_=~s/^\s+//;
				my ($first , $second) = split (/\s+/,$_,2);
				_write_chunk('',21,"/$first=\"$second\"",80);
				if ($type eq 'CDS' && $first eq 'locus_tag'){
					_write_chunk('',21,"/codon_start=1",80);
					_write_chunk('',21,"/codon_table=$global->{gcode}",80);
					_write_chunk('',21,"/translation=\"$features->{$second}\"",80);
					}
				}@information;
			}@features;

		print "ORIGIN\t\n";
		my $origin_line  = lc $contigs->{$contig}->{sequence};
		my @origin_lines = ();
		push @origin_lines , $_ for unpack("(A60)*",$origin_line);
		map {
			my $inc = $_;
			my $tmp = '';
			$tmp .= $_.' ' for unpack("(A10)*",$inc);
			chop $tmp;
			$_ = $tmp;
			}@origin_lines;
		my $counter = 1;
		map{
			print " "x(9-length($counter));
			print "$counter $_\n";
			$counter += 60;
			} @origin_lines;
		print"//\n";
		}@CONTIGS;

	}

sub _write_chunk{
	my ($header , $gap , $line, $total_width) = @_;
	die "_write_record error , header too big" if (length $header > $gap);
	if (length $line < $total_width - $gap){
		print $header.' 'x($gap-length$header).$line."\n";
		}
	else{
		my $up = $total_width-$gap-1;
		print $header.' 'x($gap-length$header). unpack("(A$up)*",$line)."\n";
		$line = substr $line,$total_width-$gap-1;
		print ' 'x$gap . $_ . "\n" for unpack("(A$up)*",$line);
		}
	}

sub usage{
print STDERR '
tbl2gff 

A small utility to convert annotation tables into GenBank formatted gbks. Requires a FASTA file 
for both the contigs that generated the table and the proteins. The resulting GBK is printed to 
STDOUT , capture it with a re-direct.

This program was written as a replacement for tbl2asn as part of the Prokka annotation pipeline 
and is not gauranteed to work anywhere else. (It isn\'t even gauranteed to work at all.)

usage:

tbl2gff -fsa <contigs in FASTA format> -faa <proteins in FASTA format> -tbl <annotation table> 

optional argument

-comment     quote delimited text for the Comment line.

'
	}