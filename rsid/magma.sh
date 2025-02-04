#!/usr/bin/bash

export MAGMA=${HPC_WORK}/MAGMA
export MSigDB=${HPC_WORK}/MSigDB

function IL.12B()
{
  (
    awk -v OFS="\t" 'BEGIN {print "SNP", "P", "NOBS"}'
    zcat ${INF}/METAL/${trait}-1.tbl.gz | \
    cut -f3,12,18 | \
    sed '1d' | \
    sort -k1,1 | \
    join INTERVAL.rsid - | \
    awk -vOFS="\t" '{print $2,10^$3,int($4+0.5)}'
  ) > ${trait}.pval
}

function All()
{
  (
    awk -v OFS="\t" 'BEGIN {print "SNP", "P", "NOBS"}'
    cut -f3,12,18 ${INF}/garfield/garfield.dat | \
    sed '1d' | \
    sort -k1,1 | \
    join INTERVAL.rsid - | \
    awk -vOFS="\t" '{print $2,10^$3,int($4+0.5)}'
  ) > ${trait}.pval
}

function run_magma()
{
# Annotation
awk -vOFS="\t" '{print $2,$1,$4}' ${MAGMA}/g1000_eur.bim > g1000_eur.snploc
magma --annotate window=50,50 --snp-loc g1000_eur.snploc --gene-loc ${MAGMA}/NCBI37.3.gene.loc --out ${trait}

# Gene analysis - SNP p-values
magma --bfile ${MAGMA}/g1000_eur --pval ${trait}.pval ncol=NOBS --gene-annot ${trait}.genes.annot --out ${trait}

# Pathway analysis
# http://software.broadinstitute.org/gsea/downloads.jsp
magma --gene-results ${trait}.genes.raw --set-annot ${MSigDB}/msigdb.v6.2.entrez.gmt self-contained --model fwer --out ${trait}

R --no-save -q <<END
  options(width=250)
  sets <- function(db)
  {
    sets.out <- read.table(paste0(db,".sets.out"), as.is=TRUE, skip=3, header=TRUE)
    ordered <- with(sets.out, order(P))
    require(gap)
    with(sets.out,{
      summary(P)
      pdf(paste0(db,".sets.pdf"))
      qqunif(P)
      dev.off()
    })
    keep_var <- !(names(sets.out)%in%"SET")
    sets.out[ordered, keep_var]
  }

  db <- Sys.getenv("trait")
  magma <- sets(db)
  ord <- with(magma,order(P))
  set <- magma[ord,]
  set <- within(set,{fdr <- p.adjust(P,"fdr")})
  save(set,file=paste0(db,".rda"))
  write.table(subset(set[c("FULL_NAME","NGENES","BETA","SE","P","fdr")],fdr<=0.05),file=paste0(db,".dat"),row.names=FALSE,quote=FALSE,sep="\t")

END
}
cd work

# export trait=IL.12B
# IL.12B 
export trait=All
All
run_magma
cd -
