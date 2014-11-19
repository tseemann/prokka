# Prokka: rapid prokaryotic genome annotation  

Torsten Seemann <torsten.seemann@monash.edu>  
Victorian Bioinformatics Consortium, AUSTRALIA <http://vicbioinformatics.com>

##Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Invoking Prokka](#invoking-prokka)
- [Output Files](#output-files)
- [Command line options](#command-line-options)
- [Dependencies](#dependencies)
- [Databases](#databases)
- [FAQ](#faq)
- [Still To Do](#still-to-do)
- [Changes](#changes)
- [Citation](#citation)

##Introduction

Whole genome annotation is the process of identifying features of interest
in a set of genomic DNA sequences, and labelling them with useful
information. Prokka is a software tool to annotate bacterial, archaeal and
viral genomes quickly and produce standards-compliant output files.

##Installation

###Download

Download the latest `prokka-1.xx.tar.gz` archive from http://www.bioinformatics.net.au/software.prokka.shtml

###Extract

Choose somewhere to put it, for example in your home directory (no root access required):

    % cd $HOME
    % tar zxvf prokka-1.xx.tar.gz
    % ls prokka-1.xx

###Add to PATH

Add the following line to your `$HOME/.bashrc` file, 
or to `/etc/profile.d/prokka.sh` to make it available to all users:

    export PATH=$PATH:$HOME/prokka-1.xx/bin

###Index the sequence databases

    % prokka --setupdb

###Install dependencies

Prokka comes with many binaries for Linux and Mac OS X. It will always use your existing installed versions if they exist, but will use the included ones if that fails. For some older systems (eg. Centos 4.x) some of them won't work due to them being dynamically linked against new GLIBC libraries you don't have. 

You can consult the list of dependencies later in this document.

###Choose a rRNA predictor

####Option 1 - Don't use one

If Prokka can't find a predictor for rRNA featues (either Barrnap or RNAmmer below) then it simply won't annotate any. Most people don't care that much about them anyway,

####Option 2 - Barrnap

This was written by the author of Prokka and is recommended if you prefer speed over absolute accuracy. It uses the new multi-core NHMMER for DNA:DNA profile searches. Download it from http://www.vicbioinformatics.com/software.barrnap.shtml

####Option 3 - RNAmmer

RNAmmer was written when HMMER 2.x was the latest release. Since them, HMMER 3.x has been released, and uses the same executable binary names. Prokka needs HMMER3 and RNAmmer (and hence HMMER2) so you need to edit your RNAmmer script to explicitly point your HMMER2 binary instead of using the HMMER3 binary which is more likely to be in your PATH first.

Type which rnammer to find the script, and then edit it with your favourite editor. Find the following lines at the top:

    if ( $uname eq "Linux" ) {
    #       $HMMSEARCH_BINARY = "/usr/cbs/bio/bin/linux64/hmmsearch";    # OLD
            $HMMSEARCH_BINARY = "/path/to/my/hmmer-2.3.2/bin/hmmsearch"; # NEW (yours)
    }

If you are using Mac OS X, you'll also have to change the `"Linux"` to `"Darwin"` too. As you can see, I have commented out the original part, and replaced it with the location of my HMMER2 hmmsearch tool, so it doesn't run the HMMER3 one. You need to ensure HMMER3 is in your PATH before the old HMMER2 too.

###Test

* Type `prokka` and it should output it's help screen.
* Type `prokka --version` and you should see an output like `prokka 1.x`
* Type `prokka --listdb` and it will show you what databases it has installed to use.


##Invoking Prokka

###Beginner

    # Vanilla (but with free toppings)
    % prokka contigs.fa
     
    # Look for a folder called PROKKA_yyyymmdd (today's date) and look at stats
    % cat PROKKA_yyyymmdd/*.txt

###Moderate

    # Choose the names of the output files
    % prokka --outdir mydir --prefix mygenome contigs.fa
     
    # Visualize it in Artemis
    % art mydir/mygenome.gff

###Expert

    # It's not just for bacteria, people
    % prokka --kingdom Archaea --outdir mydir --genus Pyrococcus --locustag PYCC
     
    # Search for my favourite gene
    % exonerate --bestn 1 zetatoxin.fasta mydir/PYCC_06072012.faa | less

###Wizard

    # Watch and learn
    % prokka --outdir mydir --locustag EHEC --proteins NewToxins.faa --evalue 0.001 --partialgenes --gram neg --addgenes contigs.fa
     
    # Check to see if anything went really wrong
    % less mydir/EHEC_06072012.err
     
    # Add final details using Sequin
    % sequin mydir/EHEC_0607201.sqn

###Genbank submitter

    # Register your BioProject and your locus_tag prefix first!
    % prokka --compliant --centre UoN --outdir PRJNA123456 --locustag EHEC --prefix EHEC-Chr1 contigs.fa
     
    # Check to see if anything went really wrong
    % less PRJNA123456/EHEC-Chr1.err
     
    # Add final details using Sequin
    % sequin PRJNA123456/EHEC-Chr1.sqn

###Crazy Person

    # No stinking Perl script is going to control me
    % prokka \
        --outdir $HOME/genomes/Ec_POO247 --force \
        --prefix Ec_POO247 --addgenes --locustag ECPOOp \
        --increment 10 --gffver 2 --centre CDC  --compliant \
        --genus Escherichia --species coli --strain POO247 --plasmid pECPOO247 \
        --kingdom Bacteria --gcode 11 --usegenus \
        --proteins /opt/prokka/db/trusted/Ecocyc-17.6 \
        --evalue 1e-9 --rfam \
        plasmid-closed.fna


##Output Files

| Extension | Description |
| --------- | ----------- |
| .gff | This is the master annotation in GFF3 format, containing both sequences and annotations. It can be viewed directly in Artemis or IGV. |
| .gbk | This is a standard Genbank file derived from the master .gff. If the input to prokka was a multi-FASTA, then this will be a multi-Genbank, with one record for each sequence. |
| .fna | Nucleotide FASTA file of the input contig sequences. |
| .faa | Protein FASTA file of the translated CDS sequences. |
| .ffn | Nucleotide FASTA file of all the annotated sequences, not just CDS. |
| .sqn | An ASN1 format "Sequin" file for submission to Genbank. It needs to be edited to set the correct taxonomy, authors, related publication etc. |
| .fsa | Nucleotide FASTA file of the input contig sequences, used by "tbl2asn" to create the .sqn file. It is mostly the same as the .fna file, but with extra Sequin tags in the sequence description lines. |
| .tbl | Feature Table file, used by "tbl2asn" to create the .sqn file. |
| .err | Unacceptable annotations - the NCBI discrepancy report. |
| .log | Contains all the output that Prokka produced during its run. This is a record of what settings you used, even if the --quiet option was enabled. |
| .txt | Statistics relating to the annotated features found. |

##Command line options

    General:
      --help            This help
      --version         Print version and exit
      --docs            Show full manual/documentation
      --citation        Print citation for referencing Prokka
      --quiet           No screen output (default OFF)
    Setup:
      --listdb          List all configured databases
      --setupdb         Index all installed databases
      --cleandb         Remove all database indices
      --depends         List all software dependencies
    Outputs:
      --outdir [X]      Output folder [auto] (default '')
      --force           Force overwriting existing output folder (default OFF)
      --prefix [X]      Filename output prefix [auto] (default '')
      --addgenes        Add 'gene' features for each 'CDS' feature (default OFF)
      --locustag [X]    Locus tag prefix (default 'PROKKA')
      --increment [N]   Locus tag counter increment (default '1')
      --gffver [N]      GFF version (default '3')
      --compliant       Force Genbank/ENA/DDJB compliance: --genes --mincontiglen 200 --centre XXX (default OFF)
      --centre [X]      Sequencing centre ID. (default '')
    Organism details:
      --genus [X]       Genus name (default 'Genus')
      --species [X]     Species name (default 'species')
      --strain [X]      Strain name (default 'strain')
      --plasmid [X]     Plasmid name or identifier (default '')
    Annotations:
      --kingdom [X]     Annotation mode: Archaea|Bacteria|Mitochondria|Viruses (default 'Bacteria')
      --gcode [N]       Genetic code / Translation table (set if --kingdom is set) (default '0')
      --gram [X]        Gram: -/neg +/pos (default '')
      --usegenus        Use genus-specific BLAST databases (needs --genus) (default OFF)
      --proteins [X]    Fasta file of trusted proteins to first annotate from (default '')
      --metagenome      Improve gene predictions for highly fragmented genomes (default OFF)
      --partialgenes    Allow genes to run off edges, yielding incomplete genes (no closed ends option in prodigal) (default OFF)
      --rawproduct      Do not clean up /product annotation (default OFF)
    Computation:
      --fast            Fast mode - skip CDS /product searching (default OFF)
      --cpus [N]        Number of CPUs to use [0=all] (default '8')
      --mincontiglen [N] Minimum contig size [NCBI needs 200] (default '1')
      --evalue [n.n]    Similarity e-value cut-off (default '1e-06')
      --rfam            Enable searching for ncRNAs with Infernal+Rfam (SLOW!) (default '0')
      --norrna          Don't run rRNA search (default OFF)
      --notrna          Don't run tRNA search (default OFF)
      --rnammer         Prefer RNAmmer over Barrnap for rRNA prediction (default OFF)

##Dependencies

* __GNU Parallel__  
A shell tool for executing jobs in parallel using one or more computers  
_O. Tange, GNU Parallel - The Command-Line Power Tool, ;login: The USENIX Magazine, Feb 2011:42-47._

* __BioPerl__  
Used for input/output of various file formats  
_Stajich et al, The Bioperl toolkit: Perl modules for the life sciences. Genome Res. 2002 Oct;12(10):1611-8._

* __Aragorn__  
Finds transfer RNA features (tRNA)  
_Laslett D, Canback B. ARAGORN, a program to detect tRNA genes and tmRNA genes in nucleotide sequences. Nucleic Acids Res. 2004 Jan 2;32(1):11-6._

* __Barrnap__  
Used to predict ribosomal RNA features (rRNA). My licence-free replacement for RNAmmmer.  
_Manuscript under preparation._

* __RNAmmer__  
Finds ribosomal RNA features (rRNA)  
_Lagesen K et al. RNAmmer: consistent and rapid annotation of ribosomal RNA genes. Nucleic Acids Res. 2007;35(9):3100-8._

* __Prodigal__  
Finds protein-coding features (CDS)  
_Hyatt D et al. Prodigal: prokaryotic gene recognition and translation initiation site identification. BMC Bioinformatics. 2010 Mar 8;11:119._

* __SignalP__  
Finds signal peptide features in CDS (sig_peptide)  
_Petersen TN et al. SignalP 4.0: discriminating signal peptides from transmembrane regions. Nat Methods. 2011 Sep 29;8(10):785-6._

* __BLAST+__  
Used for similarity searching against protein sequence libraries  
_Camacho C et al. BLAST+: architecture and applications. BMC Bioinformatics. 2009 Dec 15;10:421._

* __HMMER3__  
Used for similarity searching against protein family profiles  
_Finn RD et al. HMMER web server: interactive sequence similarity searching. Nucleic Acids Res. 2011 Jul;39(Web Server issue):W29-37._

* __Infernal__  
Used for similarity searching against ncRNA family profiles  
_D. L. Kolbe, S. R. Eddy. Fast Filtering for RNA Homology Search. Bioinformatics, 27:3102-3109, 2011._


##Databases

###The Core (BLAST+) Databases

Prokka uses a variety of databases when trying to assign function to the predicted CDS features. It takes a hierarchial approach to make it fast. A small, core set of well characterized proteins are first searched using BLAST+. This combination of small database and fast search typically completes about 70% of the workload. Then a series of slower but more sensitive HMM databases are searched using HMMER3.

The initial core databases are derived from UniProtKB; there is one per "kingdom" supported. To qualify for inclusion, a protein must be (1) from Bacteria (or Archaea or Viruses); (2) not be "Fragment" entries; and (3) have an evidence level ("PE") of 2 or lower, which corresponds to experimental mRNA or proteomics evidence.

####Making a Core Databases

If you want to modify these core databases, the included script `prokka-uniprot_to_fasta_db`, along with the official `uniprot_sprot.dat`, can be used to generate a new database to put in `/opt/prokka/db/kingdom/`. If you add new ones, the command `prokka --listdb` will show you whether it has been detected properly.

####The Genus Databases

If you enable `--usegenus` and also provide a Genus via `--genus` then it will first use a BLAST database which is Genus specific. Prokka comes with a set of databases for the most common Bacterial genera; type prokka `--listdb` to see what they are.

####Adding a Genus Databases

If you have a set of Genbank files and want to create a new Genus database, Prokka comes with a tool called 
`prokka-genbank_to_fasta_db` to help. For example, if you had four annotated "Coccus" genomes, you could do the following:

    % prokka-genbank_to_fasta_db Coccus1.gbk Coccus2.gbk Coccus3.gbk Coccus4.gbk > Coccus.faa
    % cd-hit -i Coccus.faa -o Coccus -T 0 -M 0 -g 1 -s 0.8 -c 0.9
    % rm -fv Coccus.faa Coccus.bak.clstr Coccus.clstr
    % makeblastdb -dbtype prot -in Coccus
    % mv Coccus.p* /path/to/prokka/db/genus/
 
###The HMM Databases

Prokka comes with a bunch of HMM libraries for HMMER3. They are mostly Bacteria-specific. They are searched after the core and genus databases. You can add more simply by putting them in `/opt/prokka/db/hmm`. Type `prokka --listdb` to confirm they are recognised.

###FASTA database format

Prokka understands two annotation tag formats, a plain one and a detailed one.

The plain one is a standard FASTA-like line with the ID after the `>` sign, and the protein `/product` 
after the ID (the "description" part of the line):

    >SeqID product

The detailed one consists of a special encoded three-part description line. The parts are the `/EC_number`, 
the `/gene` code, then the `/product` - and they are separated by a special "~~~" sequence:

    >SeqID EC_number~~~gene~~~product

Here are some examples. Note that not all parts need to be present, but the "~~~" should still be there:

    >YP_492693.1 2.1.1.48~~~ermC~~~rRNA adenine N-6-methyltransferase
    MNEKNIKHSQNFITSKHNIDKIMTNIRLNEHDNIFEIGSGKGHFTLELVQRCNFVTAIEI
    DHKLCKTTENKLVDHDNFQVLNKDILQFKFPKNQSYKIFGNIPYNISTDIIRKIVF*
    >YP_492697.1 ~~~traB~~~transfer complex protein TraB
    MIKKFSLTTVYVAFLSIVLSNITLGAENPGPKIEQGLQQVQTFLTGLIVAVGICAGVWIV
    LKKLPGIDDPMVKNEMFRGVGMVLAGVAVGAALVWLVPWVYNLFQ*
    >YP_492694.1 ~~~~~~transposase
    MNYFRYKQFNKDVITVAVGYYLRYALSYRDISEILRGRGVNVHHSTVYRWVQEYAPILYQ
    QSINTAKNTLKGIECIYALYKKNRRSLQIYGFSPCHEISIMLAS*

The same description lines apply to HMM models, except the "NAME" and "DESC" fields are used:

    NAME  PRK00001
    ACC   PRK00001
    DESC  2.1.1.48~~~ermC~~~rRNA adenine N-6-methyltransferase
    LENG  284
    
    
##FAQ

* __Where does the name "Prokka" come from?__  
Prokka is a contraction of "prokaryotic annotation". It's also relatively unique within Google, and also rhymes with a native Australian marsupial called the quokka.

* __Can I annotate by eukaryote genome with Prokka?__  
No. Prokka is specifically designed for Bacteria, Archaea and Viruses. It can't handle multi-exon gene models; I would recommend using MAKER 2 for that purpose.

* __Why does Prokka keeps on crashing when it gets to tge "tbl2asn" stage?__  
It seems that the tbl2asn program from NCBI "expires" after 12 months, and refuses to run. Unfortunately you need to install a newer version which you can download from here.

* __The hmmscan step seems to hang and do nothing?__      
The problem here is GNU Parallel. It seems the Debian package for hmmer has modified it to require the `--gnu` option to behave in the 'default' way. There is no clear reason for this. The only way to restore normal behaviour is to edit the prokka script and change `parallel` to `parallel --gnu`.

* __Why does prokka fail when it gets to hmmscan?__  
Unfortunately HMMER keeps changing it's database format, and they aren't upward compatible. If you upgraded HMMER (from 3.0 to 3.1 say) then you need to "re-press" the files. This can be done as follows:
    cd /path/to/prokka/db/hmm
    mkdir new
    for D in *.hmm ; do hmmconvert $D > new/$D ; done
    cd new
    for D in *.hmm ; do hmmpress $D ; done
    mv * ..
    rmdir new

* __Why does Prokka take so long to download?__  
Our server is in Australia, and the international pipes aren't always flowing as well as we'd like. I try to put it on GoogleDrive. Dropbox is no longer possible due to bandwidth quotas. If you are able to mirror Prokka (~2 GB) outside please let me know.

* __Why can't I load Prokka .GBK files into Mauve?__  
Mauve uses BioJava to parse GenBank files, and it is very picky about Genbank files. 
It does not like long contig names,
like those from Velvet or Spades. One solution is to use `--centre XXX` 
in Prokka and it will rename all your contigs to be NCBI (and Mauve)
compliant. It does not like the ACCESSION and VERSION strings that Prokka
produces via the "tbl2asn" tool. The following Unix command will fix them:
`egrep -v '^(ACCESSION|VERSION)' prokka.gbk > mauve.gbk`


##Still To Do

* ToDoList.txt: https://github.com/Victorian-Bioinformatics-Consortium/prokka/blob/master/doc/ToDoList.txt


##Changes

* ChangeLog.txt: https://raw.githubusercontent.com/Victorian-Bioinformatics-Consortium/prokka/master/doc/ChangeLog.txt
* Github commits: https://github.com/Victorian-Bioinformatics-Consortium/prokka/commits/master

##Citation

Seemann T.  
*Prokka: rapid prokaryotic genome annotation*  
**Bioinformatics** 2014 Jul 15;30(14):2068-9.
[PMID:24642063](http://www.ncbi.nlm.nih.gov/pubmed/24642063)  
