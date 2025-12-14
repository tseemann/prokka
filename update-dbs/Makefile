

DIR := ../db/kingdom
DIR_B := $(DIR)/Bacteria
DIR_A := $(DIR)/Archaea
DIR_V := $(DIR)/Viruses
DIR_M := $(DIR)/Mitochondria

EVID := 2
UNIPROT := ./UniProt-to-sprot.pl --evidence $(EVID) 
RMDUP := seqkit rmdup --by-seq

CP := cp -vf

.PHONY: install all


ALL := AMR sprot_b sprot_v sprot_a

all: $(ALL)

install : $(ALL)
	$(CP) AMR $(DIR_B)/AMR
	$(CP) sprot_b $(DIR_B)/sprot
	$(CP) sprot_a $(DIR_A)/sprot
	$(CP) sprot_v $(DIR_V)/sprot
#	$(CP) sprot_m $(DIR_M)/sprot
	


AMR: AMRProt.fa
	./AMRprot-to-AMR.pl $< > $@

AMRProt.fa :
	wget https://ftp.ncbi.nlm.nih.gov/pathogen/Antimicrobial_resistance/AMRFinderPlus/database/latest/AMRProt.fa

sprot_b : uniprot_sprot_bacteria.dat.gz
	 zcat $< | $(UNIPROT) | $(RMDUP) > $@

sprot_a : uniprot_sprot_archaea.dat.gz
	 zcat $< | $(UNIPROT) | $(RMDUP) > $@

sprot_v : uniprot_sprot_viruses.dat.gz
	 zcat $< | $(UNIPROT) | $(RMDUP) > $@

uniprot_sprot_bacteria.dat.gz :
	wget https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions/uniprot_sprot_bacteria.dat.gz

uniprot_sprot_archaea.dat.gz :
	wget https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions/uniprot_sprot_archaea.dat.gz

uniprot_sprot_virsues.dat.gz :
	wget https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/taxonomic_divisions/uniprot_sprot_viruses.dat.gz
			
clean :
	rm -f $(ALL)
	
	
