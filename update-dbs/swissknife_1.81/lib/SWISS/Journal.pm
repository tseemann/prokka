package SWISS::Journal;

use vars qw($AUTOLOAD @ISA @EXPORT_OK);

use Exporter;
use Carp;
use strict;
 
my %ISSN2JOURNAL = ();
my %JOURNAL2ISSN = ();
my %OLDISSN2NEWISSN = ();
my %ABBREV = ();
my $_STAGE1=0;
my $_STAGE2=0;
my $_STAGE3=0;

sub issn2name {

  my $issn=shift;

  unless (%ISSN2JOURNAL or $_STAGE1){
    _load_ISSN2JOURNAL_STAGE1();
  }

  my $newissn = $OLDISSN2NEWISSN{$issn};
  $issn=$newissn if $newissn;

  my $name = $ISSN2JOURNAL{$issn};
  
  unless ($name or $_STAGE2) {
    _load_ISSN2JOURNAL_STAGE2();
    $name = $ISSN2JOURNAL{$issn};
  }
  return $name;
}

sub name2issn {
  my $name = shift;

  return undef unless $name;

  unless ($_STAGE3){
    _load_JOURNAL2ISSN();
  }

  $name =~ tr/a-z/A-Z/;
  $name =~ tr/A-Z//cd;
  my $issn = $JOURNAL2ISSN{$name};
  return $issn;
}

sub name2swiss {  
  my $name = shift;

  return undef unless $name;

  my $issn = name2issn($name);
  if ($issn) {
    my $newname = issn2name($issn);
    return $newname if $newname;
  }

  _load_JOURNAL_ABBREV() unless %ABBREV;
  
  my @words = split(' ',$name);
  for (my $i=0; $i <= $#words; $i++) {
    my $word = $words[$i]; $word =~ s/\.//g;
    my $abbr = $ABBREV{$word};
    $words[$i] = "$abbr." if $abbr;
  }
  $name = join(' ',@words);
  return $name;
}


sub _load_ISSN2JOURNAL_STAGE1{
  carp "Loading journal data, stage 1" if $main::opt_debug>1;
  $_STAGE1=1;
  %ISSN2JOURNAL = 
  (
   '0002-9297' => 'Am. J. Hum. Genet.',
   '0099-2240' => 'Appl. Environ. Microbiol.',
   '0003-9861' => 'Arch. Biochem. Biophys.',
   '0006-291X' => 'Biochem. Biophys. Res. Commun.',
   '0264-6021' => 'Biochem. J.',
   '0006-2960' => 'Biochemistry',
   '0006-3002' => 'Biochim. Biophys. Acta',
   '0006-4971' => 'Blood',
   '0092-8674' => 'Cell',
   '0172-8083' => 'Curr. Genet.',
   '0070-217X' => 'Curr. Top. Microbiol. Immunol.',
   '0012-1606' => 'Dev. Biol.',
   '0950-1991' => 'Development',
   '0198-0238' => 'DNA',
   '1044-5498' => 'DNA Cell Biol.',
   '1340-2838' => 'DNA Res.',
   '1042-5179' => 'DNA Seq.',
   '0173-0835' => 'Electrophoresis',
   '0261-4189' => 'EMBO J.',
   '0013-7227' => 'Endocrinology',
   '0014-2956' => 'Eur. J. Biochem.',
   '0014-5793' => 'FEBS Lett.',
   '0378-1097' => 'FEMS Microbiol. Lett.',
   '0378-1119' => 'Gene',
   '0890-9369' => 'Genes Dev.',
   '0016-6731' => 'Genetics',
   '0888-7543' => 'Genomics',
   '0340-6717' => 'Hum. Genet.',
   '0964-6906' => 'Hum. Mol. Genet.',
   '1059-7794' => 'Hum. Mutat.',
   '0093-7711' => 'Immunogenetics',
   '0019-9567' => 'Infect. Immun.',
   '0021-9193' => 'J. Bacteriol.',
   '0021-924X' => 'J. Biochem.',
   '0021-9258' => 'J. Biol. Chem.',
   '0021-9525' => 'J. Cell Biol.',
   '0021-9738' => 'J. Clin. Invest.',
   '0022-1007' => 'J. Exp. Med.',
   '0022-1287' => 'J. Gen. Microbiol.',
   '0022-1317' => 'J. Gen. Virol.',
   '0022-1767' => 'J. Immunol.',
   '0022-2836' => 'J. Mol. Biol.',
   '0022-2844' => 'J. Mol. Evol.',
   '0022-538X' => 'J. Virol.',
   '1350-0872' => 'Microbiology',
   '0166-6851' => 'Mol. Biochem. Parasitol.',
   '0737-4038' => 'Mol. Biol. Evol.',
   '0270-7306' => 'Mol. Cell. Biol.',
   '0888-8809' => 'Mol. Endocrinol.',
   '0026-8925' => 'Mol. Gen. Genet.',
   '0950-382X' => 'Mol. Microbiol.',
   '1061-4036' => 'Nat. Genet.',
   '1072-8368' => 'Nat. Struct. Biol.',
   '0028-0836' => 'Nature',
   '0896-6273' => 'Neuron',
   '0305-1048' => 'Nucleic Acids Res.',
   '0950-9232' => 'Oncogene',
   '1040-4651' => 'Plant Cell',
   '0167-4412' => 'Plant Mol. Biol.',
   '0735-9640' => 'Plant Mol. Biol. Rep.',
   '0032-0889' => 'Plant Physiol.',
   '0027-8424' => 'Proc. Natl. Acad. Sci. U.S.A.',
   '0961-8368' => 'Protein Sci.',
   '0036-8075' => 'Science',
   '0969-2126' => 'Structure',
   '0042-6822' => 'Virology',
   '0168-1702' => 'Virus Res.',
   '0749-503X' => 'Yeast',
  );

  %OLDISSN2NEWISSN = 
  (
   '0301-5610' => '0305-1048', # Nucleic Acids Res
  );

}

sub _load_ISSN2JOURNAL_STAGE2{
  carp "Loading journal data, stage 2" if $main::opt_debug>1;
  
  my $save = $/; $/="\n";
  while (<DATA>) {
    if (/^(\d\d\d\d-\d\d\d\S),(.*)/) {
      print STDERR "Read $1|$2\n" if $main::opt_debug>3;
      $ISSN2JOURNAL{$1}=$2;
    } else {
      last;
    }
  }
  $/ = $save;
  $_STAGE2 = 1;
}

sub _load_JOURNAL2ISSN {

  _load_ISSN2JOURNAL_STAGE1() unless $_STAGE1;
  _load_ISSN2JOURNAL_STAGE2() unless $_STAGE2;
  carp "Loading journal data, stage 3" if $main::opt_debug>1;

  while (my($issn,$name) = each %ISSN2JOURNAL){
    next if $OLDISSN2NEWISSN{$issn};
    $name =~ tr/a-z/A-Z/;
    $name =~ tr/A-Z//cd;
    $JOURNAL2ISSN{$name} = $issn;
  }
  $_STAGE3 = 1;
}

sub _load_JOURNAL_ABBREV {
  my @abbrev =
    ('Acad','Adhes','Adv','Alcohol','Am','An','Anal','Anat','Androl','Anim',
     'Ann','Annu','Anthropol','Antibiot','Antimicrob','Appl','Arch',
     'Arterioscler','Assoc','Autoimmun','Bacteriol','Biochem','Biochim',
     'Bioenerg','Biokhim','Biol','Biomed','Biomembr','Biomol','Bioorg',
     'Biophys','Biosci','Biotechnol','Boll','Br','Bras','Braz','Bull','C',
     'Calcif','Can','Carcinog','Cardiol','Cardiovasc','Cell','Chem',
     'Chemother','Chim','Chin','Cienc','Circ','Clin','Coagul','Commun',
     'Comp','Connect','Craniofac','Crit','Crystallogr','Curr','Cytochem',
     'Cytogenet','Cytol','Dent','Dermatol','Des','Dev','Diagn','Differ','Dis',
     'Discov','Disord','Dispos','Domest','Dyn','Ecol','Endocr','Endocrinol',
     'Eng','Engl','Entomol','Environ','Enzym','Enzymol','Epidemiol','Essent',
     'Eukaryot','Eur','Evol','Exp','Expr','Fertil','Fiziol','Formos','Found',
     'Funct','Gastroenterol','Gen','Genet','Glycoconj','Gynecol','Haematol',
     'Haemost','Harb','Hear','Hematol','Hepat','Hepatol','Hered','Histochem',
     'Horm','Hosp','Hum','Hyg','Hypertens','Immun','Immunobiol','Immunogenet',
     'Immunol','Immunopathol','Infect','Inflamm','Inherit','Inhib','Inorg',
     'Inst','Int','Interact','Intern','Invertebr','Invest','Isr','Ital','J',
     'Jpn','Khim','Lab','Latinoam','Lett','Leukoc','Leukot','Lipidol',
     'Macromol','Mamm','Mar','Mech','Med','Membr','Metab','Microb',
     'Microbiol','Mikrobiol','Miner','Mitt','Mol','Motil','Mutagen','Mutat',
     'Mycol','Nat','Natl','Nephrol','Netw','Neuroanat','Neurobiol',
     'Neurochem','Neuroendocrinol','Neurogenet','Neuroimmunol','Neurol',
     'Neuromuscul','Neurooncol','Neuropathol','Neurosci','Neurosurg','Nutr',
     'Oncol','Ophthalmol','Opin','Organ','Paediatr','Parasitol','Pathog',
     'Pathol','Pediatr','Pept','Perspect','Pharm','Pharmacol','Photobiol',
     'Photochem','Phylogenet','Phys','Physiol','Pol','Poult','Primatol',
     'Proc','Prog','Psychiatr','Purif','Q','Quant','R','Radiat','Rec',
     'Recept','Recognit','Regul','Rep','Reprod','Res','Respir','Rev','Rheum',
     'Rheumatol','Sang','Scand','Sci','Semin','Seq','Ser','Signal','Soc',
     'Somat','Spectrom','Sper','Stand','Struct','Submicrosc','Symp','Syst',
     'Technol','Teratog','Theor','Ther','Thromb','Top','Toxicol','Trans',
     'Transduct','Transm','Treat','Trop','Tuber','Ukr','Ups','Urol','Vasc',
     'Vet','Virol','Virusol','Vis','Vitam','Vopr','West','Z','Zh','Zool'
    );

  my $abbr;
  foreach $abbr (@abbrev){
    $ABBREV{$abbr}=$abbr;
    $ABBREV{uc($abbr)}=$abbr;
  }
}

1;

__DATA__
0001-5253,Acta Biochim. Biophys. Acad. Sci. Hung.
0582-9879,Acta Biochim. Biophys. Sin.
0001-527X,Acta Biochim. Pol.
0138-4988,Acta Biotechnol.
0095-4195,Acta Bot. Sin.
0904-213X,Acta Chem. Scand.
0567-7394,Acta Crystallogr. A
0108-7681,Acta Crystallogr. B
0907-4449,Acta Crystallogr. D
0001-5598,Acta Endocrinol.
0001-5792,Acta Haematol.
0365-463X,Acta Med. Scand. Suppl.
0137-1320,Acta Microbiol. Pol.
0001-6322,Acta Neuropathol.
0374-5600,Acta Paediatr. Jpn. Overseas Ed.
0065-1583,Acta Protozool.
0001-6675,Acta Pharm. Suec.
0001-706X,Acta Trop.
0300-8924,Acta Vitaminol. Enzymol.
0065-227X,Adv. Biophys.
0065-2571,Adv. Enzyme Regul.
0065-258X,Adv. Enzymol.
0065-2598,Adv. Exp. Med. Biol.
0084-5957,Adv. Nephrol. Necker Hosp.
0732-8141,Adv. Prostaglandin Thromboxane Leukotriene Res.
0065-3233,Adv. Protein Chem.
1040-7952,Adv. Second Messenger Phosphoprotein Res.
0065-4299,Agents Actions
0002-1369,Agric. Biol. Chem.
0269-9370,AIDS
0889-2229,AIDS Res. Hum. Retroviruses
0741-8329,Alcohol
0145-6008,Alcohol. Clin. Exp. Res.
0105-3639,Alfred Benzon Symp.
0105-4538,Allergy
0002-8444,Am. Fern J.
0002-9122,Am. J. Bot.
0361-8609,Am. J. Hematol.
0002-9297,Am. J. Hum. Genet.
0895-7061,Am. J. Hypertens.
0002-9343,Am. J. Med.
0148-7299,Am. J. Med. Genet.
0002-9629,Am. J. Med. Sci.
0002-9394,Am. J. Ophthalmol.
0002-9440,Am. J. Pathol.
0002-9483,Am. J. Phys. Anthropol.
0002-9513,Am. J. Physiol.
1046-7408,Am. J. Reprod. Immunol.
1044-1549,Am. J. Respir. Cell Mol. Biol.
1073-449X,Am. J. Respir. Crit. Care Med.
0002-9637,Am. J. Trop. Med. Hyg.
0002-9645,Am. J. Vet. Res.
0003-1569,Am. Zool.
0001-3765,An. Acad. Bras. Cienc.
0003-2697,Anal. Biochem.
1049-5398,Anim. Biotechnol.
0268-9146,Anim. Genet.
0013-8746,Ann. Entomol. Soc. Am.
0003-4002,Ann. Genet. Sel. Anim.
0003-4800,Ann. Hum. Genet.
0769-2625,Ann. Inst. Pasteur Immunol.
0769-2617,Ann. Inst. Pasteur Virol.
0026-6493,Ann. Mo. Bot. Gard.
0077-8923,Ann. N.Y. Acad. Sci.
0364-5134,Ann. Neurol.
0031-9473,Ann. Phytopathol. Soc. Jpn.
0066-4154,Annu. Rev. Biochem.
0066-4197,Annu. Rev. Genet.
0066-4227,Annu. Rev. Microbiol.
0250-7005,Anticancer Res.
0066-4804,Antimicrob. Agents Chemother.
0003-6072,Antonie Van Leeuwenhoek
0903-4641,APMIS
0273-2289,Appl. Biochem. Biotechnol.
0099-2240,Appl. Environ. Microbiol.
0175-7598,Appl. Microbiol. Biotechnol.
0954-6642,Appl. Theor. Electroph.
0003-9861,Arch. Biochem. Biophys.
0739-4462,Arch. Insect Biochem. Physiol.
0003-9799,Arch. Int. Physiol. Biochim.
0188-0128,Arch. Med. Res.
0302-8933,Arch. Microbiol.
0003-9942,Arch. Neurol.
0003-9950,Arch. Ophthalmol.
0003-9969,Arch. Oral Biol.
0003-9985,Arch. Pathol. Lab. Med.
0304-8608,Arch. Virol.
0021-4884,Arerugi
0365-6128,Ark. Kemi
1049-8834,Arterioscler. Thromb.
1079-5642,Arterioscler. Thromb. Vasc. Biol.
0276-5047,Arteriosclerosis
0004-3591,Arthritis Rheum.
0128-7451,Asia Pac. J. Mol. Biol. Biotechnol.
0044-7897,ASM News
0021-9150,Atherosclerosis
0004-9417,Aust. J. Biol. Sci.
0004-9425,Aust. J. Chem.
0310-7841,Aust. J. Plant Physiol.
0307-9457,Avian Pathol.
0090-5542,Basic Life Sci.
0301-0457,Behring Inst. Mitt.
0749-5331,Biochem. Arch.
0006-291X,Biochem. Biophys. Res. Commun.
0829-8211,Biochem. Cell Biol.
0006-2928,Biochem. Genet.
0158-5231,Biochem. Int.
0264-6021,Biochem. J.
0885-4505,Biochem. Med. Metab. Biol.
1069-8302,Biochem. Mol. Biol. Int.
1077-3150,Biochem. Mol. Med.
0006-2952,Biochem. Pharmacol.
0015-3796,Biochem. Physiol. Pflanz.
0067-8694,Biochem. Soc. Symp.
0300-5127,Biochem. Soc. Trans.
0006-2960,Biochemistry
0006-3002,Biochim. Biophys. Acta
0300-9084,Biochimie
0923-9820,Biodegradation
0265-9247,Bioessays
0951-6433,Biofactors
0006-2979,Biokhimiia
0006-3185,Biol. Bull.
0248-4900,Biol. Cell
1431-6730,Biol. Chem.
0024-4066,Biol. J. Linn. Soc. Lond.
0918-6158,Biol. Pharm. Bull.
0006-3363,Biol. Reprod.
1016-0922,Biol. Signals
0232-766X,Biomed. Biochim. Acta
0887-6134,Biomed. Environ. Mass Spectrom.
0895-3988,Biomed. Environ. Sci.
0306-042X,Biomed. Mass Spectrom.
0388-6107,Biomed. Res.
0966-0844,Biometals
0045-2068,Bioorg. Chem.
0132-3423,Bioorg. Khim.
0968-0896,Bioorg. Med. Chem.
0301-4622,Biophys. Chem.
0006-3495,Biophys. J.
0340-1057,Biophys. Struct. Mech.
0006-3525,Biopolymers
0916-8451,Biosci. Biotechnol. Biochem.
0144-8463,Biosci. Rep.
0736-6205,BioTechniques
0885-4513,Biotechnol. Appl. Biochem.
0572-6565,Biotechnol. Bioeng. Symp.
0141-5492,Biotechnol. Lett.
8756-7938,Biotechnol. Prog.
0733-222X,Biotechnology
0890-734X,Biotekhnologiya
0006-4971,Blood
0340-4684,Blood Cells
0957-5235,Blood Coagul. Fibrinolysis
0959-8138,BMJ
0037-8771,Boll. Soc. Ital. Biol. Sper.
8756-3282,Bone
0932-8629,Bot. Acta
0006-8063,Bot. Bull. Acad. Sin.
0007-0769,Br. Heart J.
0007-0920,Br. J. Cancer
0007-1048,Br. J. Haematol.
0007-1188,Br. J. Pharmacol.
0007-1935,Br. Vet. J.
0006-8993,Brain Res.
0361-9230,Brain Res. Bull.
0165-3806,Brain Res. Dev. Brain Res.
0169-328X,Brain Res. Mol. Brain Res.
0100-879X,Braz. J. Med. Biol. Res.
0009-2673,Bull. Chem. Soc. Jpn.
0037-9042,Bull. Soc. Chim. Biol.
0040-8921,Bull. Tokyo Med. Dent. Univ.
0171-967X,Calcif. Tissue Int.
0008-4018,Can. J. Biochem.
0714-7511,Can. J. Biochem. Cell Biol.
0008-4026,Can. J. Bot.
0706-652X,Can. J. Fish. Aquat. Sci.
0045-5067,Can. J. For. Res.
0008-4166,Can. J. Microbiol.
0008-4212,Can. J. Physiol. Pharmacol.
0008-4301,Can. J. Zool.
0008-543X,Cancer
0955-3541,Cancer Commun.
0165-4608,Cancer Genet. Cytogenet.
0304-3835,Cancer Lett.
0008-5472,Cancer Res.
0143-3334,Carcinogenesis
0008-6363,Cardiovasc. Res.
0105-1938,Carlsberg Res. Commun.
0092-8674,Cell
1061-5385,Cell Adhes. Commun.
0143-4160,Cell Calcium
0045-6039,Cell Differ.
0922-3371,Cell Differ. Dev.
1044-9523,Cell Growth Differ.
0886-1544,Cell Motil. Cytoskeleton
0730-9554,Cell Muscle Motil.
1044-2030,Cell Regul.
0386-7196,Cell Struct. Funct.
0302-766X,Cell Tissue Res.
0008-8749,Cell. Immunol.
0145-5680,Cell. Mol. Biol.
0968-8773,Cell. Mol. Biol. Res.
1420-682X,Cell. Mol. Life Sci.
0272-4340,Cell. Mol. Neurobiol.
0898-6568,Cell. Signal.
0009-0352,Cereal Chem.
0009-2940,Chem. Ber.
1074-5521,Chem. Biol.
0009-2797,Chem. Biol. Interact.
0009-3068,Chem. Ind.
0009-2363,Chem. Pharm. Bull.
0009-3084,Chem. Phys. Lipids
0893-228X,Chem. Res. Toxicol.
0004-2056,Chem. Scr.
0379-864X,Chem. Senses
0306-0012,Chem. Soc. Rev.
0009-4293,Chimia
1000-8543,Chin. Biochem. J.
1042-749X,Chin. J. Biotechnol.
0253-2662,Chin. J. Microbiol. Immunol.
1001-6538,Chin. Sci. Bull.
0009-5915,Chromosoma
0967-3849,Chromosome Res.
0300-5208,Ciba Found. Symp.
0009-7330,Circ. Res.
0092-6213,Circ. Shock
0009-7322,Circulation
0009-9147,Clin. Chem.
0009-8981,Clin. Chim. Acta
1071-412X,Clin. Diagn. Lab. Immunol.
0954-7894,Clin. Exp. Allergy
1064-1963,Clin. Exp. Hypertens.
0009-9104,Clin. Exp. Immunol.
0009-9163,Clin. Genet.
0090-1229,Clin. Immunol. Immunopathol.
1058-4838,Clin. Infect. Dis.
0095-8654,Clin. Orthop.
0009-9279,Clin. Res.
0143-5221,Clin. Sci.
0091-7451,Cold Spring Harb. Symp. Quant. Biol.
0174-173X,Coll. Relat. Res.
0010-0765,Collect. Czech. Chem. Commun.
0010-406X,Comp. Biochem. Physiol.
0147-9571,Comp. Immunol. Microbiol. Infect. Dis.
0253-5076,Complement
0300-8207,Connect. Tissue Res.
0045-6411,CRC Crit. Rev. Biochem.
1040-841X,CRC Crit. Rev. Microbiol.
0960-9822,Curr. Biol.
0271-3683,Curr. Eye Res.
0172-8083,Curr. Genet.
0343-8651,Curr. Microbiol.
0955-0674,Curr. Opin. Cell Biol.
0957-9672,Curr. Opin. Lipidol.
0959-440X,Curr. Opin. Struct. Biol.
0070-2137,Curr. Top. Cell. Regul.
0070-217X,Curr. Top. Microbiol. Immunol.
0301-0171,Cytogenet. Cell Genet.
1043-4666,Cytokine
0021-5406,Denpun Kagaku
0012-1606,Dev. Biol.
0301-5149,Dev. Biol. Stand.
0145-305X,Dev. Comp. Immunol.
1058-8388,Dev. Dyn.
0949-944X,Dev. Genes Evol.
0192-253X,Dev. Genet.
0012-1592,Dev. Growth Differ.
0378-5866,Dev. Neurosci.
0950-1991,Development
0012-1797,Diabetes
0012-186X,Diabetologia
0301-4681,Differentiation
0278-0240,Dis. Markers
0198-0238,DNA
1044-5498,DNA Cell Biol.
1340-2838,DNA Res.
1042-5179,DNA Seq.
0002-3264,Dokl. Akad. Nauk SSSR
0012-4958,Dokl. Biochem.
0012-4966,Dokl. Biol. Sci.
0739-7240,Domest. Anim. Endocrinol.
1055-9612,Drug Des. Discov.
0090-9556,Drug Metab. Dispos.
0424-7086,Eisei Dobutsu
0173-0835,Electrophoresis
0261-4189,EMBO J.
0743-5800,Endocr. Res.
0969-711X,Endocrine
0013-7200,Endocrinol. Exp.
0013-7219,Endocrinol. Jpn.
0013-7227,Endocrinology
0256-1514,Endocyt. Cell Res.
1062-3329,Endothelium
0091-6765,Environ. Health Perspect.
0013-9432,Enzyme
0141-0229,Enzyme Microb. Technol.
1019-6773,Enzyme Protein
1148-5493,Eur. Cytokine Netw.
0195-668X,Eur. Heart J.
0014-2956,Eur. J. Biochem.
0171-9335,Eur. J. Cell Biol.
0014-2972,Eur. J. Clin. Invest.
0804-4643,Eur. J. Endocrinol.
0902-4441,Eur. J. Haematol.
1018-4813,Eur. J. Hum. Genet.
0014-2980,Eur. J. Immunol.
0953-816X,Eur. J. Neurosci.
0340-6199,Eur. J. Pediatr.
0014-2999,Eur. J. Pharmacol.
0014-3820,Evolution
0071-3384,Exp. Biol. Med.
0014-4827,Exp. Cell Res.
0232-7384,Exp. Clin. Endocrinol.
0906-6705,Exp. Dermatol.
0014-4835,Exp. Eye Res.
0301-472X,Exp. Hematol.
0190-2148,Exp. Lung Res.
0147-5975,Exp. Mycol.
0014-4886,Exp. Neurol.
0014-4894,Exp. Parasitol.
0014-4754,Experientia
0892-6638,FASEB J.
0014-5793,FEBS Lett.
0014-9446,Fed. Proc.
0378-1097,FEMS Microbiol. Lett.
0168-6445,FEMS Microbiol. Rev.
0268-9499,Fibrinolysis
0920-1742,Fish Physiol. Biochem.
1050-4648,Fish Shellfish Immunol.
8755-0199,Free Radic. Res. Commun.
0016-5085,Gastroenterology
0016-6480,Gen. Comp. Endocrinol.
0378-1119,Gene
0735-0651,Gene Anal. Tech.
1052-2166,Gene Expr.
1356-9597,Genes Cells
1045-2257,Genes Chromosomes Cancer
0890-9369,Genes Dev.
1341-7568,Genes Genet. Syst.
0741-0395,Genet. Epidemiol.
0016-6723,Genet. Res.
0016-6707,Genetica
0016-6731,Genetics
0016-6758,Genetika
0831-2796,Genome
1088-9051,Genome Res.
1070-2830,Genome Sci. Technol.
0888-7543,Genomics
0894-1491,Glia
0959-6658,Glycobiology
0282-0080,Glycoconj. J.
0897-7194,Growth Factors
0017-5749,Gut
0090-8258,Gynecol. Oncol.
0301-0147,Haemostasis
0378-5955,Hear. Res.
0018-019X,Helv. Chim. Acta
0363-0269,Hemoglobin
0270-9139,Hepatology
0018-0661,Hereditas
0018-2214,Histochem. J.
0367-6102,Hokkaido Igaku Zasshi
0018-5043,Horm. Metab. Res.
0257-7712,Hua Hsi I Ko Ta Hsueh Hsueh Pao
0340-6717,Hum. Genet.
0001-5652,Hum. Hered.
0198-8859,Hum. Immunol.
0964-6906,Hum. Mol. Genet.
1059-7794,Hum. Mutat.
0268-1161,Hum. Reprod.
0194-911X,Hypertension
0097-9023,ICN UCLA Symp. Mol. Cell. Biol.
1074-7613,Immunity
0171-2985,Immunobiology
0019-2791,Immunochemistry
0093-7711,Immunogenetics
0818-9641,Immunol. Cell Biol.
0882-0139,Immunol. Invest.
0165-2478,Immunol. Lett.
0105-2896,Immunol. Rev.
0092-6019,Immunol. Ser.
0167-4919,Immunol. Today
0019-2805,Immunology
0883-8364,In Vitro Cell. Dev. Biol.
0019-9567,Infect. Immun.
0360-3997,Inflammation
0020-1669,Inorg. Chem.
0020-1790,Insect Biochem.
0965-1748,Insect Biochem. Mol. Biol.
0962-1075,Insect Mol. Biol.
0020-5915,Int. Arch. Allergy Appl. Immunol.
1018-2438,Int. Arch. Allergy Immunol.
0958-6946,Int. Dairy J.
0953-8178,Int. Immunol.
0105-6263,Int. J. Androl.
0020-711X,Int. J. Biochem.
1357-2725,Int. J. Biochem. Cell Biol.
0141-8130,Int. J. Biol. Macromol.
0020-7136,Int. J. Cancer
0737-1454,Int. J. Cell Cloning
0940-5437,Int. J. Clin. Lab. Res.
0214-6282,Int. J. Dev. Biol.
0168-1605,Int. J. Food Microbiol.
0925-5710,Int. J. Hematol.
0934-8840,Int. J. Med. Microbiol. Virol. Parasitol. Infect. Dis.
0020-7519,Int. J. Parasitol.
0367-8377,Int. J. Pept. Protein Res.
1058-5893,Int. J. Plant Sci.
0164-0291,Int. J. Primatol.
0020-7551,Int. J. Protein Res.
0360-3016,Int. J. Radiat. Oncol. Biol. Phys.
0020-7713,Int. J. Syst. Bacteriol.
0300-5526,Intervirology
1354-2516,Invertebr. Neurosci.
0146-0404,Invest. Ophthalmol. Vis. Sci.
0268-8220,IRCS Med. Sci.
0160-3787,Isozymes Curr. Top. Biol. Med. Res.
0021-2148,Isr. J. Chem.
0021-2938,Ital. J. Biochem.
0021-8561,J. Agric. Food Chem.
0091-6749,J. Allergy Clin. Immunol.
0002-7863,J. Am. Chem. Soc.
1046-6673,J. Am. Soc. Nephrol.
0021-8782,J. Anat.
0196-3635,J. Androl.
0021-8812,J. Anim. Sci.
0021-8820,J. Antibiot.
0305-7453,J. Antimicrob. Chemother.
0021-8847,J. Appl. Bacteriol.
0921-8971,J. Appl. Phycol.
0896-8411,J. Autoimmun.
0021-9193,J. Bacteriol.
0233-111X,J. Basic Microbiol.
0021-924X,J. Biochem.
0145-479X,J. Bioenerg. Biomembr.
0021-9258,J. Biol. Chem.
0949-8257,J. Biol. Inorg. Chem.
0925-2738,J. Biomol. NMR
0739-1102,J. Biomol. Struct. Dyn.
0250-4774,J. Biosci.
0168-1656,J. Biotechnol.
0884-0431,J. Bone Miner. Res.
0021-9525,J. Cell Biol.
0021-9533,J. Cell Sci.
0730-2312,J. Cell. Biochem.
0021-9541,J. Cell. Physiol.
0891-0618,J. Chem. Neuroanat.
0022-4936,J. Chem. Soc. Chem. Commun.
0253-5106,J. Chem. Soc. Pak.
0021-9673,J. Chromatogr.
0021-972X,J. Clin. Endocrinol. Metab.
0021-9738,J. Clin. Invest.
0095-1137,J. Clin. Microbiol.
0021-9746,J. Clin. Pathol.
0021-9967,J. Comp. Neurol.
0174-1578,J. Comp. Physiol. B
0270-4145,J. Craniofac. Genet. Dev. Biol.
0022-0299,J. Dairy Res.
0022-0302,J. Dairy Sci.
0022-0345,J. Dent. Res.
0385-2407,J. Dermatol.
0923-1811,J. Dermatol. Sci.
0022-0795,J. Endocrinol.
0391-4097,J. Endocrinol. Invest.
0968-0519,J. Endotoxin Res.
8755-5093,J. Enzym. Inhib.
1066-5234,J. Eukaryot. Microbiol.
1010-061X,J. Evol. Biol.
0022-0949,J. Exp. Biol.
0022-0957,J. Exp. Bot.
0022-1007,J. Exp. Med.
0730-8485,J. Exp. Pathol.
0022-104X,J. Exp. Zool.
0041-9419,J. Fac. Med. Baghdad
0922-338X,J. Ferment. Bioeng.
0022-1112,J. Fish Biol.
0022-1198,J. Forensic Sci.
0815-9319,J. Gastroenterol. Hepatol.
0022-1260,J. Gen. Appl. Microbiol.
0022-1287,J. Gen. Microbiol.
0022-1295,J. Gen. Physiol.
0022-1317,J. Gen. Virol.
0022-1333,J. Genet.
0022-1503,J. Hered.
0022-1554,J. Histochem. Cytochem.
0305-1811,J. Immunogenet.
0022-1767,J. Immunol.
0169-4146,J. Ind. Microbiol.
0022-1899,J. Infect. Dis.
1078-7852,J. Inflamm.
0141-8955,J. Inherit. Metab. Dis.
0162-0134,J. Inorg. Biochem.
0022-1910,J. Insect Physiol.
1079-9907,J. Interferon Cytokine Res.
0197-8357,J. Interferon Res.
0022-2011,J. Invertebr. Pathol.
0022-202X,J. Invest. Dermatol.
0022-2143,J. Lab. Clin. Med.
0741-5400,J. Leukoc. Biol.
0022-2275,J. Lipid Res.
0022-2372,J. Mammal.
1064-7554,J. Mammal. Evol.
0022-2623,J. Med. Chem.
0022-2585,J. Med. Entomol.
0022-2593,J. Med. Genet.
0022-2615,J. Med. Microbiol.
0268-1218,J. Med. Vet. Mycol.
0146-6615,J. Med. Virol.
0022-2631,J. Membr. Biol.
1017-7825,J. Microbiol. Biotechnol.
0271-6801,J. Mol. Appl. Genet.
0022-2836,J. Mol. Biol.
0022-2828,J. Mol. Cell. Cardiol.
0952-5041,J. Mol. Endocrinol.
0022-2844,J. Mol. Evol.
0263-7855,J. Mol. Graph.
0946-2716,J. Mol. Med.
0895-8696,J. Mol. Neurosci.
0952-3499,J. Mol. Recognit.
0142-4319,J. Muscle Res. Cell. Motil.
0027-8874,J. Natl. Cancer Inst.
0300-9564,J. Neural Transm.
0022-3034,J. Neurobiol.
0022-3042,J. Neurochem.
0953-8194,J. Neuroendocrinol.
0167-7063,J. Neurogenet.
0165-5728,J. Neuroimmunol.
0022-510X,J. Neurol. Sci.
0167-594X,J. Neurooncol.
0022-3069,J. Neuropathol. Exp. Neurol.
0270-6474,J. Neurosci.
0360-4012,J. Neurosci. Res.
0022-3166,J. Nutr.
0955-2863,J. Nutr. Biochem.
0022-3476,J. Pediatr.
1397-002X,J. Pept. Res.
1075-2617,J. Pept. Sci.
0373-1022,J. Pharm. Pharmacol.
0022-3565,J. Pharmacol. Exp. Ther.
0022-3646,J. Phycol.
0176-1617,J. Plant Physiol.
0035-9173,J. Proc. Royal Soc. N.S. Wales
0277-8033,J. Protein Chem.
0022-3921,J. Protozool.
0197-5110,J. Recept. Res.
1079-9893,J. Recept. Signal Transduct. Res.
0916-8818,J. Reprod. Dev.
0022-4251,J. Reprod. Fertil.
0315-162X,J. Rheumatol.
0038-2078,J. S. Afr. Chem. Inst.
0730-8000,J. Shellfish Res.
0098-843X,J. South. Calif. Dent. Assoc.
0022-4731,J. Steroid Biochem.
0960-0760,J. Steroid Biochem. Mol. Biol.
1047-8477,J. Struct. Biol.
0022-4782,J. Submicrosc. Cytol. Pathol.
0091-7419,J. Supramol. Struct.
0022-5193,J. Theor. Biol.
0022-5347,J. Urol.
0931-1793,J. Vet. Med. B
0916-7250,J. Vet. Med. Sci.
0022-538X,J. Virol.
0166-0934,J. Virol. Methods
0098-7484,JAMA
0021-5074,Jinrui Idengaku Zasshi
0091-7400,Johns Hopkins Med. J. Suppl.
0047-1828,Jpn. Circ. J.
0910-5050,Jpn. J. Cancer Res.
0021-504X,Jpn. J. Genet.
0021-5139,Jpn. J. Microbiol.
0021-5198,Jpn. J. Pharmacol.
0047-1917,Jpn. J. Vet. Res.
0075-4617,Justus Liebigs Ann. Chem.
0368-5063,Kagoshima Daigaku Igaku Zasshi
0387-5911,Kansenshogaku Zasshi
0250-7862,Kexue Tongbao
0023-1150,Khim. Prirod. Soedin.
0085-2538,Kidney Int.
0300-9149,Kokubyo Gakkai Zasshi
0378-8512,Korean J. Biochem.
0440-2413,Korean J. Microbiol.
0023-6837,Lab. Invest.
0140-6736,Lancet
1072-0502,Learning Memory
0266-8254,Lett. Appl. Microbiol.
0929-5666,Lett. Pept. Sci.
0887-6924,Leukemia
0024-3205,Life Sci.
0024-4201,Lipids
0277-6766,Lymphokine Res.
0938-8990,Mamm. Genome
0141-1136,Mar. Environ. Res.
0934-8832,Matrix
0945-053X,Matrix Biol.
0025-6153,Maydica
0047-6374,Mech. Ageing Dev.
0925-4773,Mech. Dev.
0960-8931,Melanoma Res.
0091-679X,Meth. Cell Biol.
0076-6879,Meth. Enzymol.
1090-6592,Microb. Comp. Genomics
1076-6294,Microb. Drug Resist.
0882-4010,Microb. Pathog.
0385-5600,Microbiol. Immunol.
0944-5013,Microbiol. Res.
0146-0749,Microbiol. Rev.
1350-0872,Microbiology
0026-3788,Milchwissenschaft
0166-6851,Mol. Biochem. Parasitol.
0026-8933,Mol. Biol.
1059-1524,Mol. Biol. Cell
0737-4038,Mol. Biol. Evol.
0735-1313,Mol. Biol. Med.
0301-4851,Mol. Biol. Rep.
0899-1987,Mol. Carcinog.
1097-2765,Mol. Cell
0300-8177,Mol. Cell. Biochem.
0270-7306,Mol. Cell. Biol.
1065-3074,Mol. Cell. Differ.
0303-7207,Mol. Cell. Endocrinol.
1044-7431,Mol. Cell. Neurosci.
0890-8508,Mol. Cell. Probes
1016-8478,Mol. Cells
1044-7393,Mol. Chem. Neuropathol.
0962-1083,Mol. Ecol.
0888-8809,Mol. Endocrinol.
0026-8925,Mol. Gen. Genet.
0161-5890,Mol. Immunol.
1053-6426,Mol. Mar. Biol. Biotechnol.
1076-1551,Mol. Med.
0968-7688,Mol. Membrane Biol.
0950-382X,Mol. Microbiol.
0893-7648,Mol. Neurobiol.
0026-895X,Mol. Pharmacol.
1055-7903,Mol. Phylogenet. Evol.
0894-0282,Mol. Plant Microbe Interact.
1040-452X,Mol. Reprod. Dev.
0026-9247,Monatsh. Chem.
0148-639X,Muscle Nerve
0027-5107,Mutat. Res.
0953-7562,Mycol. Res.
0027-7649,Nagoya Med. J.
1087-0156,Nat. Biotechnol.
0385-6283,Nat. Cult.
1061-4036,Nat. Genet.
0254-7600,Nat. Immun. Cell Growth Regul.
1078-8956,Nat. Med.
1072-8368,Nat. Struct. Biol.
1056-9014,Nat. Toxins
0028-0836,Nature
0090-0028,Nature New Biol.
0028-1042,Naturwissenschaften
0028-1298,Naunyn Schmiedebergs Arch. Pharmacol.
0028-209X,Neth. Milk Dairy J.
0197-4580,Neurobiol. Aging
0197-0186,Neurochem. Int.
0364-3190,Neurochem. Res.
0028-3835,Neuroendocrinology
1021-7401,Neuroimmunomodulation
0028-3878,Neurology
0960-8966,Neuromuscul. Disord.
0896-6273,Neuron
0143-4179,Neuropeptides
0028-3908,Neuropharmacology
0893-133X,Neuropsychopharmacology
0959-4965,Neuroreport
0304-3940,Neurosci. Lett.
0168-0102,Neurosci. Res.
0893-6609,Neurosci. Res. Commun.
0306-4522,Neuroscience
1043-4674,New Biol.
0028-4793,New Engl. J. Med.
0914-5818,Nihon Hosenkin Gakkai Shi
0048-0444,Nippon Ika Daigaku Zasshi
0047-1852,Nippon Rinsho
0029-4810,Nouv. Rev. Fr. Hematol.
0305-1048,Nucleic Acids Res.
0309-1872,Nucleic Acids Res. Spec. Publ.
0261-3166,Nucleic Acids Symp. Ser.
0950-9232,Oncogene
0890-6467,Oncogene Res.
0030-3747,Ophthalmic Res.
0161-6420,Ophthalmology
0902-0055,Oral Microbiol. Immunol.
0030-493X,Org. Mass Spectrom.
0885-3177,Pancreas
1383-5769,Parasitol. Int.
0932-0113,Parasitol. Res.
0031-1820,Parasitology
0048-2951,Parassitologia
1054-9803,PCR Methods Appl.
0031-3998,Pediatr. Res.
0892-0672,Pediatrics
1040-5704,Pept. Res.
0196-9781,Peptides
0031-613X,Pestic. Sci.
0031-6768,Pflugers Arch.
0724-8741,Pharm. Res.
0960-314X,Pharmacogenetics
1043-6618,Pharmacol. Res.
0163-7258,Pharmacol. Ther.
0031-8655,Photochem. Photobiol.
0166-8595,Photosyn. Res.
0031-9325,Physiol. Chem. Phys.
0885-5765,Physiol. Mol. Plant Pathol.
0031-9317,Physiol. Plantarum
0031-9368,Physiol. Veg.
0031-9422,Phytochemistry
0031-949X,Phytopathology
0893-5785,Pigment Cell Res.
1000-8721,Ping Tu Hsueh Pao
1040-4651,Plant Cell
0032-0781,Plant Cell Physiol.
0721-7714,Plant Cell Rep.
0960-7412,Plant J.
0167-4412,Plant Mol. Biol.
0735-9640,Plant Mol. Biol. Rep.
0032-0889,Plant Physiol.
0981-9428,Plant Physiol. Biochem.
0168-9452,Plant Sci.
0304-4211,Plant Sci. Lett.
0378-2697,Plant Syst. Evol.
0032-0935,Planta
0147-619X,Plasmid
0032-5791,Poult. Sci.
0032-7484,Prep. Biochem.
0027-8424,Proc. Natl. Acad. Sci. U.S.A.
0037-9727,Proc. Soc. Exp. Biol. Med.
0083-8969,Proc. West. Pharmacol. Soc.
0079-6123,Prog. Brain Res.
0361-7742,Prog. Clin. Biol. Res.
0079-6751,Prog. Respir. Res.
0090-6980,Prostaglandins
0952-3278,Prostaglandins Leukot. Essent. Fatty Acids
0269-2139,Protein Eng.
1046-5928,Protein Expr. Purif.
0929-8665,Protein Pept. Lett.
0961-8368,Protein Sci.
0931-9506,Protein Seq. Data Anal.
0887-3585,Proteins
0955-8829,Psychiatr. Genet.
0033-4545,Pure Appl. Chem.
0951-4198,Rapid Commun. Mass Spectrom.
0079-9963,Recent Prog. Horm. Res.
1060-6823,Recept. Channels
1052-8040,Receptor
0167-0115,Regul. Pept.
1031-3613,Reprod. Fertil. Dev.
0923-2508,Res. Microbiol.
0034-5288,Res. Vet. Sci.
0923-2516,Res. Virol.
0338-4535,Rev. Fr. Transfus. Immunohematol.
0187-4640,Rev. Latinoam. Microbiol.
0047-1860,Rinsho Byori
1355-8382,RNA
1068-1620,Russ. J. Bioorg. Chem.
0379-4350,S. Afr. J. Chem.
0038-2353,S. Afr. J. Sci.
0257-2389,Sanop Misaengmul Hakhoe Chi
0036-472X,Sapporo Igaku Zasshi
0036-5521,Scand. J. Gastroenterol.
0300-9475,Scand. J. Immunol.
0036-8733,Sci. Am.
0250-7870,Sci. Sin.
0036-8075,Science
0031-9082,Seibutsubutsurikagaku
0037-1017,Seikagaku
0734-8630,Semin. Reprod. Endocrinol.
1044-5773,Semin. Virol.
0934-0882,Sex. Plant Reprod.
0253-9918,Shengwu Huaxue Yu Shengwu Wuli Jinzhan
0029-8484,Shigaku
0037-5349,Silvae Genetica
0583-421X,Singmul Hakhoe Chi
0740-7750,Somat. Cell Mol. Genet.
0360-4497,Sov. J. Bioorg. Chem.
0038-5638,Sov. Phys. Crystallogr.
0039-128X,Steroids
0039-2499,Stroke
0969-2126,Structure
0081-6337,Studia Biophys.
0039-6060,Surgery
0723-2020,Syst. Appl. Microbiol.
1063-5157,Syst. Biol.
0363-6445,Syst. Bot.
0039-7989,Syst. Zool.
0371-7682,Taiwan I Hsueh Hui Tsa Chih
1013-2791,Tanaguchi Symp. Brain Sci.
0040-4020,Tetrahedron
0040-4039,Tetrahedron Lett.
0040-4675,Tex. Rep. Biol. Med.
0040-5175,Text. Res. J.
0040-5752,Theor. Appl. Genet.
0093-691X,Theriogenology
0340-6245,Thromb. Haemost.
0049-3848,Thromb. Res.
0165-6090,Thymus
1050-7256,Thyroid
0001-2815,Tissue Antigens
0041-008X,Toxicol. Appl. Pharmacol.
0731-9193,Toxicologist
0041-0101,Toxicon
0066-0132,Trans. Am. Soc. Neurochem.
0066-9458,Trans. Assoc. Am. Physicians
0041-1132,Transfusion
0962-8819,Transgenic Res.
0041-1337,Transplantation
0376-5067,Trends Biochem. Sci.
1043-2760,Trends Endocrinol. Metab.
0168-9525,Trends Genet.
0378-5912,Trends Neurosci.
0165-6147,Trends Pharmacol. Sci.
0177-2392,Trop. Med. Parasitol.
0041-4093,Tumor Res.
0201-8470,Ukr. Biokhim. Zh.
0300-9734,Ups. J. Med. Sci.
0264-410X,Vaccine
0165-2427,Vet. Immunol. Immunopathol.
0378-1135,Vet. Microbiol.
0042-4900,Vet. Rec.
0165-7380,Vet. Res. Commun.
0042-6822,Virology
0920-8569,Virus Genes
0168-1702,Virus Res.
0952-5238,Vis. Neurosci.
0042-6989,Vision Res.
0300-0281,Viva Orig.
0042-8809,Vopr. Med. Khim.
0042-9007,Vox Sang.
0908-665X,Xenotransplantation
0749-503X,Yeast
0372-8609,Z. Vererbungsl.
0044-4529,Zh. Evol. Biokhim. Fiziol.
0372-9311,Zh. Mikrobiol. Epidemiol. Immunobiol.
0250-3263,Zool. Res.
0289-0003,Zool. Sci.
0967-1994,Zygote
