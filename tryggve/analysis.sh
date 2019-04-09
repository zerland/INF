# 9-4-2019 JHZ

source tryggve/analysis.ini

function qml()
{
  echo "--> Q-Q/Manhattan/LocusZoom plots"
  export rt=$HOME/INF
  (
    echo -e "chrom\tstart\tend\tgene\tprot"
    sort -k2,2 $rt/inf1.list > inf1.tmp
    cut -f2,3,7-10 $rt/doc/olink.inf.panel.annot.tsv  | \
    awk -vFS="\t" -vOFS="\t" '(NR>1){
        gsub(/\"/,"",$0)
        if($2=="Q8NF90") $3="FGF5"
        if($2=="Q8WWJ7") $3="CD6"
        print
    }' | \
    sort -t$'\t' -k2,2 | \
    join -t$'\t' -j2 inf1.tmp - | \
    awk -vFS="\t" -vOFS="\t" '{print $5,$6,$7,$4,$2}' | \
    sort -k1,1n -k2,2n
  ) > st.bed
  ls METAL/*-1.tbl.gz | \
  sed 's|METAL/||g;s/-1.tbl.gz//g' | \
  parallel -j4 --env rt -C' ' 'export protein={}; R --no-save -q < $rt/tryggve/qqman.R'
  ls METAL/*-1.tbl.gz | \
  sed 's|METAL/||g;s/-1.tbl.gz//g' | \
  parallel -j3 -C' ' '
  (
     echo -e "MarkerName\tP-value\tWeight"
     grep -w {} st.bed | \
     awk -vOFS="\t" -vM=1000000 "{start=\$2-M;if(start<0) start=0;end=\$3+M;\$2=start;\$3=end};1" > st.tmp
     read chrom start end gene prot < st.tmp
     gunzip -c METAL/{}-1.tbl.gz | \
     awk -vOFS="\t" -vchr=$chrom -vstart=$start -vend=$end \
         "(\$1 == chr && \$2 >= start && \$2 <= end){split(\$3,a,\"_\");print a[1],\$12,\$14}"
  )  > METAL/{}.lz'
  ls METAL/*-1.tbl.gz | \
  sed 's|METAL/||g;s/-1.tbl.gz//g' | \
  parallel -j1 -C' ' '
     grep -w {} st.bed | \
     awk -vOFS="\t" -vM=1000000 "{start=\$2-M;if(start<0) start=0;end=\$3+M;\$2=start;\$3=end};1" > st.tmp
     read chrom start end gene prot < st.tmp
     cd METAL
     rm -f ld_cache.db
     locuszoom --source 1000G_Nov2014 --build hg19 --pop EUR --metal {}.lz \
               --plotonly --chr $chrom --start $start --end $end --no-date --rundir .
     mv chr${chrom}_${start}-${end}.pdf {}.lz.pdf
     pdftopng -r 300 {}.lz.pdf {}
     mv {}-000001.png {}.lz-1.png
     mv {}-000002.png {}.lz-2.png
     cd -
  '
  export PATH=/data/jinhua/ImageMagick-7.0.8-22/bin;%PATH
  convert OPG.lz-1.png -resize 130% OPG.lz-3.png
  convert \( OPG.qq.png -append OPG.manhattan.png -append OPG.lz-3.png -append \) +append OPG-qml.png
}

function clumping()
{
  echo "--> clumping"
  export rt=$HOME/INF/METAL
  ls METAL/*tbl.gz | \
  sed 's/-1.tbl.gz//g' | \
  xargs -l basename | \
  parallel -j4 --env rt -C' ' '
  if [ -f $rt/{}.clumped ]; then rm $rt/{}.clumped; fi
  plink --bfile EUR \
        --clump $rt/{}-1.tbl.gz \
        --clump-snp-field MarkerName \
        --clump-field P-value \
        --clump-kb 500 \
        --clump-p1 5e-10 \
        --clump-p2 0.01 \
        --clump-r2 0.1 \
        --mac 50 \
        --out $rt/{}
  '
  (
    grep CHR $rt/*.clumped | \
    head -1
    ls METAL/*-1.tbl.gz | \
    sed 's|METAL/||g;s/-1.tbl.gz//g' | \
    parallel -j1 --env rt -C' ' 'grep -H -v CHR $rt/{}.clumped | sed "s/.clumped://g"'
  ) | \
  sed 's|'"$rt"'/||g;s/.clumped://g' | \
  awk '(NF>1){$3="";print}' | \
  awk '{$1=$1;if(NR==1)$1="prot";print}' > INF1.clumped
  R --no-save -q <<\ \ END
    require(gap)
    clumped <- read.table("INF1.clumped",as.is=TRUE,header=TRUE)
    hits <- merge(clumped[c("CHR","BP","SNP","prot")],inf1[c("prot","uniprot")],by="prot")
    names(hits) <- c("prot","Chr","bp","SNP","uniprot")
    cistrans <- cis.vs.trans.classification(hits)
    sink("INF1.clumped.out")
    with(cistrans,table)
    sink()
    sum(with(cistrans,table))
    pdf("INF1.circlize.pdf")
    circos.cis.vs.trans.plot(hits="INF1.clumped")
    dev.off()
  END
}

function mpfr()
{
  echo "--> METAL results containing P-value=0"
  awk '($5==0)' INF1.clumped | \
  cut -d' ' -f1 | 
  uniq > INF1.z
  cat INF1.z | \
  parall -j2 --env rt '
  (
    export port={}
    gunzip -c $rt/{}-1.tbl.gz | \
    awk -vOFS="\t" "NR==1||\$12!=0"
    gunzip -c $rt/{}-1.tbl.gz | \
    awk -vOFS="\t" "(NR==1||\$12==0)" > {}.z
    R --no-save -q <<\ \ \ \ END
      prot <- Sys.getenv("prot")
      metal <- read.delim(paste0(prot,".z"),as.is=TRUE)
      library(Rmpfr)
      metal <- within(metal,{P.value=format(2*pnorm(mpfr(-abs(z),100),lower.tail=TRUE,log.p=FALSE))})
      write.table(metal,file=paste0(prot,".p"),sep=\"\\t\",row.names=FALSE,quote=FALSE)
    END
    awk "NR>1" {}.p
  )'
}

function top_signals()
{
  echo "--> top signals"
  export rt=$HOME/INF/METAL
  ls METAL/*clumped | \
  sed 's|METAL/||g;s/.clumped//g' | \
  xargs -l basename | \
  parallel -j4 --env rt -C' ' '
  (
     grep -w {} st.bed | \
     awk -vOFS="\t" -vM=1000000 "{start=\$2-M;if(start<0) start=0;end=\$3+M;\$2=start;\$3=end};1" > st.tmp
     read chrom start end gene prot < st.tmp
     head -1 $rt/{}.clumped
     awk -vchr=$chrom "(NR > 1 && \$1==chr)" $rt/{}.clumped | \
     sort -k3,3 | \
     join -v1 -13 -21 - MHC.snpid | \
     sort -k2,2n -k3,3n
  ) > $rt/{}.top
  '
}

function ma()
{
  echo "--> .ma"
  export rt=$HOME/INF/METAL
  ls METAL/*.tbl.gz | \
  sed 's/-1.tbl.gz//g' | \
  xargs -l basename | \
  parallel -j4 --env rt -C' ' '
  (
    echo SNP A1 A2 freq b se p N;
    gunzip -c $rt/{}-1.tbl.gz | \
    awk "(NR>1 && \$14>50) {print \$3, \$4, \$5, \$6, \$10, \$11, \$12, \$14}"
  ) > $rt/{}.ma
  '
}
#1 Chromosome
#2 Position
#3 MarkerName
#4 Allele1
#5 Allele2
#6 Freq1
#7 FreqSE
#8 MinFreq
#9 MaxFreq
#10 Effect
#11 StdErr
#12 P-value
#13 Direction
#14 N

function cojo()
{
  echo "--> COJO analysis"
  export rt=$HOME/INF/METAL
  ls METAL/*.tbl.gz | \
  sed 's/-1.tbl.gz//g' | \
  xargs -l basename | \
  parallel -j2 --env rt -C' ' '
  if [ -f $rt/{}.jma.cojo ]; then rm $rt/{}.jma.cojo $rt/{}.ldr.cojo; fi; \
  gcta64 --bfile EUR --cojo-file $rt/{}.ma --cojo-slct --cojo-p 5e-10 --cojo-collinear 0.1 --cojo-wind 500 \
         --maf 0.01 --thread-num 2 --out $rt/{}
  '
  (
    grep SNP $rt/*.jma.cojo | \
    head -1
    grep -v -w SNP $rt/*.jma.cojo
  ) | \
  sed 's|'"$rt"'/||g;s/.jma.cojo:/\t/g' | \
  awk -vOFS="\t" '{if(NR==1) $1="prot";print}' > INF1.jma
  sed 's/Chr/CHR/g;s/bp/BP/g' cojo/INF1.1KG.r2-0.1.jma > jma
  R --no-save -q <<\ \ END
    require(gap)
    cojo <- read.table("jma",as.is=TRUE,header=TRUE)
    hits <- merge(cojo[c("prot","CHR","BP","SNP")],inf1[c("prot","uniprot")],by="prot")
    names(hits) <- c("prot","Chr","bp","SNP","uniprot")
    cistrans <- cis.vs.trans.classification(hits)
    sink("cojo/INF1.jma.out")
    with(cistrans,table)
    sink()
    sum(with(cistrans,table))
    pdf("INF1.jma.pdf")
    circos.cis.vs.trans.plot(hits="jma")
    dev.off()
  END
  rm jma
}
#1 MarkerName
#2 Allele1
#3 Allele2
#4 Freq1
#5 FreqSE
#6 MinFreq
#7 MaxFreq
#8 Effect
#9 StdErr
#10 P-value
#11 Direction
#12 CHR
#13 POS
#14 WEIGHT

function aild()
{
  echo "--> approximately independent LD blocks"
  awk 'NR>1{gsub(/chr/,"",$1);print}' tryggve/EURLD.bed > rlist-EURLD
  export rt=$HOME/INF/AILD
  ls $rt/METAL/*tbl.gz | \
  sed 's/-1.tbl.gz//g' | \
  xargs -l basename | \
  parallel -j5 --env rt -C' ' '
  plink --bfile EUR \
        --clump $rt/METAL/{}-1.tbl.gz --clump-range rlist-EURLD --clump-range-border 250 \
        --clump-snp-field MarkerName \
        --clump-field P-value \
        --clump-p1 5e-10 --clump-p2 0.01 --clump-r2 0.1 \
        --mac 50 \
        --out $rt/{}'
  (
    grep CHR $rt/*.clumped.ranges | \
    head -1
    ls METAL/*-1.tbl.gz | \
    sed 's|METAL/||g;s/-1.tbl.gz//g' | \
    parallel -j1 --env rt -C' ' 'grep -H -v CHR $rt/{}.clumped.ranges | sed "s/.clumped.ranges://g"'
  ) | \
  sed 's|'"$rt"'/||g;s/.clumped://g' | \
  awk '(NF>1){$3="";print}' | \
  awk '{$1=$1;if(NR==1)$1="prot";print}' > INF1.ranges
  awk '(NR>1){
    chr=$1;
    gsub(/chr/,"",chr);
    flanking=($3-$2)/2/1000
    centre=$2+flanking
    print sprintf("%d %d %d %s", chr, centre, flanking,$4)
  }' tryggve/EURLD.bed > rlist=EURLD.region

  for prot in $(ls $rt/METAL/*tbl.gz | sed 's/-1.tbl.gz//g' | xargs -l basename)
  do
    export p=$prot
    # bruteforceclumpingbyregion
    cat rlist=EURLD.region | \
    parallel -j8 --env p --env rt -C' ' '
     gcta64 --bfile EUR --cojo-file $rt/METAL/$p.ma --cojo-slct --cojo-p 5e-10 --maf 0.0001 \
            --extract-region-bp {1} {2} {3} --thread-num 3 --out $rt/LDBLOCK/$p-{4}'
     (
       cat $rt/LDBLOCK/${p}*.jma.cojo | head -1
       awk "NR>1" $rt/LDBLOCK/${p}*.jma.cojo
     ) > $rt/${p}.jma
  done
}

function annotate()
{
  echo "--> Variant annotation"
  export annovar_home=/services/tools/annovar/2018apr16
  export humandb=$annovar_home/humandb
  export example=$annovar_home/example
  $annovar_home/annotate_variation.pl --geneanno -otherinfo -buildver hg19 $example/ex1.avinput $humandb/ --outfile ex1
}

function nodup()
# notes from https://www.biostars.org/p/264584/
{
  echo "--> remove duplicates"
  export LC_ALL=C
  (
    grep '^#' input.vcf
    grep -v "^#" input.vcf | \
    sort -t $'\t' -k1,1 -k2,2n -k4,4 | \
    awk -F '\t' 'BEGIN {prev="";} {key=sprintf("%s\t%s\t%s",$1,$2,$4);if(key==prev) next;print;prev=key;}'
  )
}

$1

# 96, MMP.12 (CVD II)
# 97, MMP.9 (CVD III)
# 153, TNFRSF12A (UnitProt ID Q9NP84) (reported in Sun et al. but nonoverlapped with CVD/INF)
#     ~ MMP.9 connection on PLoS One by Yang et al. (2018)
