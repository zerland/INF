# 13-11-2018 JHZ

## build the lists
if [ ! -d METAL ]; then mkdir METAL; fi
rm -f METAL/METAL.tmp
touch METAL/METAL.tmp
for dir in EGCUT_INF INTERVAL NSPHS_INF ORCADES STABILITY STANLEY VIS
do
   ls sumstats/$dir | \
   awk -vdir=$dir '{
      s=$1
      gsub(dir,"",s)
      gsub(/EGCUT|NSPHS/,"",s)
      gsub(/\_autosomal|\_X_female|\_X_male|\_lah1-|\_swe6-|.gz|@/,"",s)
      gsub(/^\./,"",s)
      gsub(/@/,"",$1)
      print s " " ENVIRON["HOME"] "/INF/sumstats/" dir "/" $1
   }' >> METAL/METAL.tmp
done
sort -k1,1 METAL/METAL.tmp > METAL/METAL.list

# generate METAL command files
for p in $(cut -f1 inf1.list)
do
(
   echo SEPARATOR TAB
   echo COLUMNCOUNTING STRICT
   echo CHROMOSOMELABEL CHR
   echo POSITIONLABEL POS
   echo CUSTOMVARIABLE N
   echo LABEL N as N
   echo TRACKPOSITIONS ON
   echo AVERAGEFREQ ON
   echo MINMAXFREQ ON
   echo ADDFILTER >= 50
   echo MARKERLABEL SNPID
   echo ALLELELABELS EFFECT_ALLELE REFERENCE_ALLELE
   echo EFFECTLABEL BETA
   echo PVALUELABEL PVAL
   echo WEIGHTLABEL N
   echo FREQLABEL CODE_ALL_FQ
   echo STDERRLABEL SE
   echo SCHEME STDERR
   echo GENOMICCONTROL OFF
   echo OUTFILE $HOME/INF/METAL/$p- .tbl
   echo $p | join METAL/METAL.list - | awk '{$1="PROCESS"; print}'
   echo ANALYZE
   echo CLEAR
) > METAL/$p.metal
done

# conducting the analysis 
# module load metal/20110325 parallel/20170822
ls METAL/*.metal | \
sed 's/.metal//g' | \
parallel --env HOME -j3 -C' ' '
  metal $HOME/INF/{}.metal; \
  gzip -f $HOME/INF/{}-1.tbl
'

# obtain largest M -- the union of SNP lists as initially requested by NSPHS

function largest_M()
{
  for dir in EGCUT_INF INTERVAL LifeLinesDeep ORCADES PIVUS STABILITY STANLEY ULSAM VIS
  do
    export file=sumstats/$dir/$(ls sumstats/$dir -rS | tail -n 1 | sed 's/@//g;s/.gz//g')
    echo $file
    gunzip -c $file | awk 'NR>1' | cut -f1 | cut -d' ' -f1 > /data/jinhua/M/$dir
  done

  export female=$(ls sumstats/EGCUT_INF/**X_female* -rS | tail -n 1 | sed 's/@//g')
  export male=$(ls sumstats/EGCUT_INF/**X_male* -rS | tail -n 1 | sed 's/@//g')
  gunzip -c $female | awk 'NR>1' | cut -f1 | cut -d' ' -f1 > /data/jinhua/M/EGCUT_X_female
  gunzip -c $male | awk 'NR>1' | cut -f1 | cut -d' ' -f1 > /data/jinhua/M/EGCUT_X_male

  cd /data/jinhua/M
  cat EGCUT_INF EGCUT_X_female EGCUT_X_male INTERVAL ORCADES STABILITY STANLEY VIS | \
  sort | \
  uniq > /data/jinhua/M/M.union
  cd -
}

largest_M
