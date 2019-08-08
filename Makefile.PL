use strict;
use warnings;
 
#use 5.026; # commented in favor of MIN_PERL_VERSION
 
use ExtUtils::MakeMaker;

# Some help from
# http://blogs.perl.org/users/michal_wojciechowski/2011/11/github-friendly-readme-files-with-extutils-makemaker-and-module-build.html
my $preop = 'true';

WriteMakefile1(
  NAME         => 'Prokka',
  VERSION_FROM => 'bin/prokka',
  ABSTRACT     => 'prokka genome annotator',
  AUTHOR       => 'Torsten Seemann',
  EXE_FILES    => [
    "bin/prokka",
    "bin/prokka-abricate_to_fasta_db",
    "bin/prokka-biocyc_to_fasta_db",
    "bin/prokka-build_kingdom_dbs",
    "bin/prokka-cdd_to_hmm",
    "bin/prokka-clusters_to_hmm",
    "bin/prokka-genbank_to_fasta_db",
    "bin/prokka-genpept_to_fasta_db",
    "bin/prokka-hamap_to_hmm",
    "bin/prokka-make_tarball",
    "bin/prokka-tigrfams_to_hmm",
    "bin/prokka-uniprot_to_fasta_db",
  ],
  PREREQ_PM    => {
    # Core modules
    # Other
    "Time::Piece"    => 0,
    "XML::Simple"    => 0,
    "Digest::MD5"    => 0,
    "Bio::Perl"      => 0,
  },
  BUILD_REQUIRES => {
    'Test::More'     => 0.47,
  },
  MIN_PERL_VERSION => '5.16.1',
  LICENSE          => "gpl_3",
  dist=>{
    COMPRESS => "gzip -9f",
    SUFFIX   => "gz",
    PREOP    => $preop,
  },
  META_MERGE => {
    'meta-spec' => { version => 2 },
    resources => {
      repository => {
        type => 'git',
        url => 'git://github.com/tseemann/prokka.git',
        web => 'https://github.com/tseemann/prokka',
      },
    },
  },
);

sub WriteMakefile1 {  #Compatibility code for old versions of EU::MM. Written by Alexandr Ciornii, version 2. Added by eumm-upgrade.
  my %params=@_;
  my $eumm_version=$ExtUtils::MakeMaker::VERSION;
  $eumm_version=eval $eumm_version;
  die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
  die "License not specified" if not exists $params{LICENSE};
  if ($params{AUTHOR} and ref($params{AUTHOR}) eq 'ARRAY' and $eumm_version < 6.5705) {
    $params{META_ADD}->{author}=$params{AUTHOR};
    $params{AUTHOR}=join(', ',@{$params{AUTHOR}});
  }
  if ($params{TEST_REQUIRES} and $eumm_version < 6.64) {
    $params{BUILD_REQUIRES}={ %{$params{BUILD_REQUIRES} || {}} , %{$params{TEST_REQUIRES}} };
    delete $params{TEST_REQUIRES};
  }
  if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
    #EUMM 6.5502 has problems with BUILD_REQUIRES
    $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
    delete $params{BUILD_REQUIRES};
  }
  delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
  delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
  delete $params{META_MERGE} if $eumm_version < 6.46;
  delete $params{META_ADD} if $eumm_version < 6.46;
  delete $params{LICENSE} if $eumm_version < 6.31;

  WriteMakefile(%params);
}
