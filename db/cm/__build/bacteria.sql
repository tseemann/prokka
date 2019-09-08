SELECT DISTINCT f.rfam_acc, f.type, f.description
FROM taxonomy tx
INNER JOIN rfamseq rf ON rf.ncbi_id = tx.ncbi_id
INNER JOIN full_region fr ON fr.rfamseq_acc = rf.rfamseq_acc
INNER JOIN family f ON f.rfam_acc = fr.rfam_acc
WHERE ((f.type LIKE 'Gene;' AND f.description NOT LIKE '%transfer-messenger RNA')
OR f.type LIKE '%CRISPR;'
OR f.type LIKE '%antisense;'
OR f.type LIKE '%antitoxin;'
OR f.type LIKE '%miRNA;'
OR f.type LIKE '%ribozyme;'
OR f.type LIKE '%sRNA;'
OR f.type LIKE '%snRNA%'
OR f.type LIKE 'Intron;'
OR f.type LIKE 'Cis-reg;'
OR f.type LIKE '%IRES;'
OR f.type LIKE '%frameshift_element;'
OR f.type LIKE '%leader;'
OR f.type LIKE '%riboswitch;'
OR f.type LIKE '%thermoregulator;')
AND tx.tax_string LIKE 'Bacteria%';
