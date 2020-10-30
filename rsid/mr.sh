#!/usr/bin/bash

function MR_dat()
{
cut -f3 work/INF1.METAL | sed '1d' | sort | uniq | grep -w -f - work/INF1.merge.genes | \
parallel -j1 -C' ' '
  echo --- {2} ---
  gunzip -c METAL/{2}-1.tbl.gz | \
  cut -f1-6,10-12,18 | \
  awk -vchr={3} -vstart={4} -vend={5} -vM=1e6 -vlogp=-5.45131 "
      {
        if(ENVIRON["suffix"]=="cis") {if(\$1==chr && \$2>=start-M && \$2 <= end+M && \$9<=logp) print} else if(\$9<=logp) print
      }" > work/mr/{2}.mri-${suffix}
  cut -f3 work/mr/{2}.mri-${suffix} > work/mr/{2}.mrs-${suffix}
  plink --bfile INTERVAL/cardio/INTERVAL --extract work/mr/{2}.mrs-${suffix} \
        --geno 0.1 --mind 0.1 --maf 0.005 --indep-pairwise 1000kb 1 0.1 --out work/mr/{2}-${suffix}
  (
    echo -e "rsid\tChromosome\tPosition\tAllele1\tAllele2\tFreq1\tEffect\tStdErr\tlogP\tN"
    grep -w -f work/mr/{2}-${suffix}.prune.in work/mr/{2}.mri-${suffix} | \
    awk "{\$3=\"chr\"\$1\":\"\$2;\$8=-\$8;print}" | \
    sort -k3,3 | \
    join -23 -12 work/snp_pos - | \
    cut -d" " -f1 --complement | \
    tr " " "\t"
  ) | gzip -f > work/mr/{2}.mrx-${suffix}
'
}

cut -f3,8,9,10 doc/olink.inf.panel.annot.tsv | grep -v BDNF | sed 's/"//g' | sort -k1,1 | join -12 work/inf1.tmp - > work/INF1.merge.genes
if [ ! -d work/mr ]; then mkdir work/mr; fi
for type in cis pan; do export suffix=${type}; MR_dat; done

R --no-save <rsid/mr.R
