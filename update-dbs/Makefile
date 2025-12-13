
DBDIR=../db/kingdom/Bacteria

.PHONY: install all

all: AMR

install : AMR
	cp -fv $< $(DBDIR)/$<

AMR: AMRProt.fa
	./AMRprot-to-AMR.pl $< > $@

AMRProt.fa :
	wget https://ftp.ncbi.nlm.nih.gov/pathogen/Antimicrobial_resistance/AMRFinderPlus/database/latest/AMRProt.fa
		
clean :
	rm -f AMR AMRProt.fa 
