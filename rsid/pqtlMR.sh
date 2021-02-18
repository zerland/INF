#/usr/bin/bash

module load gcc/6
if [ ! -d ${INF}/mr/pQTLs ]; then mkdir -p ${INF}/mr/pQTLs; fi

function collect()
{
  echo ${prefix} -- ${id} -- ${trait}
  (
    cat ${prefix}_*result.txt | head -1
    grep -w ${id} ${prefix}_*result.txt | grep "Wald ratio"
  ) | grep -v _rev_ > ${prefix}-${id}.result
  (
    cat ${prefix}_*single.txt | head -1
    grep -w ${id} ${prefix}_*single.txt | grep -v -e Egger -e Inverse
  ) | grep -v _rev_ > ${prefix}-${id}.single
}
function collect_rev()
{
  echo ${prefix} -- ${id} -- ${trait}
  (
    cat ${prefix}_*result.txt | head -1
    grep -w ${id} ${prefix}_*result.txt | grep "Wald ratio"
  ) | awk 'NR==1||$1~/rev/' > ${prefix}-${id}.result
  (
    cat ${prefix}_*single.txt | head -1
    grep -w ${id} ${prefix}_*single.txt | grep -v -e Egger -e Inverse
  ) | awk 'NR==1||$1~/rev/' > ${prefix}-${id}.single
}

function iv()
{
  (
    echo SNP Phenotype effect_allele other_allele eaf beta se pval
  # rsid prot Allele1 Allele2 Freq1 Effect StdErr log.P. cis.trans
    cut -f2,3,6,7,8-11,21 ${INF}/work/INF1.METAL | \
    awk -vtype=${type} 'NR>1 && $9==type {print $1,$2,toupper($3),toupper($4),$5,$6,$7,10^$8}'
  ) > ${INF}/mr/pQTLs/INF1_${type}.ins
  if [ ${type} == "pan" ]; then
    cut -f2,3,6,7,8-11,21 ${INF}/work/INF1.METAL | \
    awk -vtype=${type} 'NR>1 {print $1,$2,toupper($3),toupper($4),$5,$6,$7,10^$8}' >> ${INF}/mr/pQTLs/INF1_${type}.ins
  fi
}

function INF1()
{
export nrows=$(sed '1d' ${INF}/mr/pQTLs/INF1_${type}.ins | wc -l)
parallel -C' ' '
export outcomes={1}
export row={2}
R --no-save -q <<END
    INF <- Sys.getenv("INF")
    outcomes <- Sys.getenv("outcomes")
    ieugwasr::gwasinfo(id = outcomes)
    row <- Sys.getenv("row")
    type <- Sys.getenv("type")
    ivs <- read.table(file.path(INF,"mr","pQTLs",paste0("INF1_",type,".ins")),as.is=TRUE,header=TRUE)
    prefix <- file.path(INF,"mr","pQTLs",paste0("INF1_",outcomes,"-",ivs[row,"Phenotype"],"-",type))
    pQTLtools::pqtlMR(ivs[row,],outcomes,prefix=prefix)
    unlink(paste0(prefix,c("-heterogeneity.txt","-pleiotropy.txt")))
    prefix <- file.path(INF,"mr","pQTLs",paste0("INF1_rev_",outcomes,"-",ivs[row,"Phenotype"],"-",type))
    pQTLtools::pqtlMR(ivs[row,],outcomes,prefix=prefix,reverse=TRUE)
    unlink(paste0(prefix,c("-heterogeneity.txt","-pleiotropy.txt")))
END
' ::: $(cat ${INF}/rsid/opengwas-id.txt) ::: $(seq ${nrows})
export nrows=$(cat ${INF}/rsid/opengwas-id.txt | wc -l)
for i in $(seq ${nrows})
do
    export id=$(awk -vnr=${i} 'NR==nr{print $1}' ${INF}/rsid/opengwas-id.txt)
    export prefix=${INF}/mr/pQTLs/INF1
    collect
    export prefix=${INF}/mr/pQTLs/INF1_rev
    collect_rev
done
}

function efo()
{
export nrows=$(sed '1d' ${INF}/mr/pQTLs/INF1_${type}.ins | wc -l)
parallel -C' ' '
export outcomes={1}
export row={2}
R --no-save -q <<END
    INF <- Sys.getenv("INF")
    outcomes <- Sys.getenv("outcomes")
    row <- Sys.getenv("row")
    type <- Sys.getenv("type")
    ivs <- read.table(file.path(INF,"mr","pQTLs",paste0("INF1_",type,".ins")),as.is=TRUE,header=TRUE)
    prefix <- file.path(INF,"mr","pQTLs",paste0("efo_",outcomes,"-",ivs[row,"Phenotype"],"-",type))
    pQTLtools::pqtlMR(ivs[row,],outcomes,prefix=prefix)
    unlink(paste0(prefix,c("-heterogeneity.txt","-pleiotropy.txt")))
    prefix <- file.path(INF,"mr","pQTLs",paste0("efo_rev_",outcomes,"-",ivs[row,"Phenotype"],"-",type))
    pQTLtools::pqtlMR(ivs[row,],outcomes,prefix=prefix,reverse=TRUE)
    unlink(paste0(prefix,c("-heterogeneity.txt","-pleiotropy.txt")))
END
' ::: $(sed '1d' ${INF}/rsid/efo.txt | cut -f4) ::: $(seq ${nrows})
export nrows=$(sed '1d' ${INF}/rsid/efo.txt | wc -l | cut -d' ' -f1)
for i in $(seq ${nrows})
do
    export trait=$(sed '1d' ${INF}/rsid/efo.txt | awk -vFS="\t" -vnr=${i} 'NR==nr{print $2}')
    export id=$(sed '1d' ${INF}/rsid/efo.txt | awk -vFS="\t" -vnr=${i} 'NR==nr{print $4}')
    export prefix=${INF}/mr/pQTLs/efo
    collect
    export prefix=${INF}/mr/pQTLs/efo_rev
    collect_rev
done
}

for type in cis trans
do
  export type=${type}
  iv
  INF1
  efo
done

  do
      for single in $(ls ${prefix}*-cis-*single ${prefix}*-trans-*single | tr ' ' '\n' | grep -v rev)
      do
      echo ${single}
      done
  done
(
  for prefix in ${INF}/mr/pQTLs/{INF1,efo}
  do
      export all=$(ls ${prefix}*-cis-*single.txt ${prefix}*-trans-*single.txt | tr ' ' '\n' | grep -v rev | wc -l)
      export p=$(bc -l <<< 0.05/${all})
      echo ${all} ${p}
      echo all results
      awk -vp=${p} -vFS="\t" -vOFS="\t" '$NF<p{split($1,a,"-");print $2,a[6],a[7],$6,$7,$8,$9}' ${prefix}-*single
      echo how many proteins
      awk -vp=${p} -vFS="\t" -vOFS="\t" '$NF<p{split($1,a,"-");print $2,a[6],a[7],$6,$7,$8,$9}' ${prefix}-*single | cut -f2 | sort | uniq | wc -l
      echo proteins with >1 diseases
      awk -vp=${p} -vFS="\t" -vOFS="\t" '$NF<p{split($1,a,"-");print $2,a[6],a[7],$6,$7,$8,$9}' ${prefix}-*single | awk 'a[$2]++>1' | \
      cut -f2 | sort | uniq
      awk -vp=${p} -vFS="\t" -vOFS="\t" '$NF<p{split($1,a,"-");print $2,a[6],a[7],$6,$7,$8,$9}' ${prefix}-*single | awk 'a[$2]++>1' | \
      cut -f2 | sort | uniq | wc -l
  done
) > ${INF}/mr/pqtlMR.out

# INF1 awk 'NR==3,NR==36' ${INF}/mr/pqtlMR.out | sed 's/|| id:/\t/' | xsel -i
# efo  awk 'NR==54,NR==150' ${INF}/mr/pqtlMR.out | sed 's/|| id:/\t/' | xsel -i

# bidirectionality test for FGF.5
R --no-save -q <<END
  options(width=200)
  INF1_cis <- read.delim("INF1_cis.ins",sep=" ")
  pQTLtools::pqtlMR(subset(INF1_cis,Phenotype=="FGF.5"),"ieu-a-7",prefix="test")
  h <- read.delim("test-harmonise.txt")
  require(TwoSampleMR)
  info <- ieugwasr::gwasinfo("ieu-a-7")
# binary outcomes
  lor <- with(h,beta.outcome)
  af <- with(h,eaf.outcome)
  ncase <- with(info,ncase)
  ncontrol <- with(info,ncontrol)
  prevalence <- 0.1
  pval.exposure <- with(h,pval.exposure)
  samplesize.exposure <- 11787
  outcome <- with(info,sample_size)
  r.exposure <- get_r_from_pn(pval.exposure,samplesize.exposure)
  r.outcome <- get_r_from_lor(lor, af, ncase, ncontrol, prevalence, model = "logit", correction = FALSE)
  h <- data.frame(h,samplesize.exposure=11787,r.exposure=r.exposure,r.outcome=r.outcome)
  directionality_test(h)
END
