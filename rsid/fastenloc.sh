#!/usr/bin/bash

export trait=$1
export eQTL=${HOME}/genetics/VCF-liftover

cd work
(
  awk -v OFS='\t' 'BEGIN{print "#chrom","chromStart","chromEnd","MarkerName","z"}'
  gunzip -c ${INF}/METAL/${trait}-1.tbl.gz | \
  awk -v OFS='\t' 'NR>1 {print "chr" $1,$2-1,$2,$3,$10/$11}'
) | \
bedtools intersect -a ${HOME}/FM-pipeline/1KG/EUR.bed -b - -wa -wb | \
awk -v OFS='\t' 'NR>1{print $8,$4,$9}' | \
sort -k1,1 | \
join <(cat INTERVAL.rsid | tr ' ' '\t') ${trait}.torus.zval -t$'\t'| \
cut -f2,3,4 | \
awk '{gsub(/region/,"",$2)};1' | \
sort -k2,2n | \
awk -vOFS='\t' '{print $1,"loc" $2,$3}' | \
gzip -f > ${trait}.torus.zval.gz

torus -d ${trait}.torus.zval.gz --load_zval -dump_pip ${trait}.gwas.pip
gzip -f ${trait}.gwas.pip

for tissue in $(cat ${eQTL}/Tissue)
do
  fastenloc -eqtl ${eQTL}/gtex_v8.eqtl_annot_rsid.hg19.vcf.gz -gwas ${trait}.gwas.pip.gz -thread 4 -tissue ${tissue} -prefix ${trait}-${tissue}
  for o in sig snp
  do
    export o=${o}
    cp ${trait}-${tissue}.enloc.${o}.out ${trait}-${tissue}-${o}.out
    join -12 <(awk 'NR>1' ${trait}.enloc.${o}.out | awk '{split($1,a,":");print a[1]}' | zgrep -w -f - ensGtp.txt.gz | cut -f1,2 | sort -k2,2) \
             <(gunzip -c ensemblToGeneName.txt.gz | sort -k1,1) | \
    cut -d' ' -f2,3 | \
    parallel --env o -C' ' 'sed -i "s/{1}/{1}-{2}/g;s/:[1-9]//g" ${trait}-${tissue}-${o}.out'
  done
done

cd -

# wget http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/ensemblToGeneName.txt.gz
# wget http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/ensGtp.txt.gz
