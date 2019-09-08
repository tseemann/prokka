#!/usr/bin/env bash
# Inspired by https://github.com/tseemann/prokka/issues/243#issuecomment-341672420

rfamversion=14.1

if [ ! -f Rfam.cm ]; then
    wget ftp://ftp.ebi.ac.uk/pub/databases/Rfam/${rfamversion}/Rfam.cm.gz
    gunzip Rfam.cm.gz
fi

for tax in archaea bacteria viruses; do
    mysql --user rfamro --host mysql-rfam-public.ebi.ac.uk --port 4497 --database Rfam \
        < ${tax}.sql \
        | tail -n +2 \
        > Rfam_${tax}_${rfamversion}.txt
    cmfetch -o Rfam_${tax}.cm -f Rfam.cm Rfam_${tax}_${rfamversion}.txt
    cmconvert -o ${tax} -b Rfam_${tax}.cm
done

mv archaea ../Archaea
mv bacteria ../Bacteria
mv viruses ../Viruses
