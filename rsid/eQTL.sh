R --no-save <<END
  options(width=200)
  library(pQTLtools)
  cvt <- read.csv("work/INF1.merge.cis.vs.trans")
  cvt_cis <- merge(subset(cvt,cis),inf1[c("gene","ensembl_gene_id")],by.x="p.gene",by.y="gene")
  cis_dat <- within(cvt_cis,{seqnames <- paste0("chr",Chr); start <- as.integer(bp-1); end <- as.integer(bp)})
  ord_cis <- with(cis_dat,order(Chr,bp))
  cis_dat <- data.frame(cis_dat[ord_cis,c("seqnames","start","end","SNP","uniprot","prot","p.gene","ensembl_gene_id","p.start","p.end")])
  cis_gr <- with(cis_dat,GenomicRanges::GRanges(seqnames=seqnames,IRanges::IRanges(start,end)))
  hpc_work <- Sys.getenv("HPC_WORK")
  path = file.path(hpc_work, "bin", "hg19ToHg38.over.chain")
  library(rtracklayer)
  ch = import.chain(path)
  ch
  seqlevelsStyle(cis_gr) <- "UCSC"
  cis38 <- liftOver(cis_gr, ch)
  class(cis38)
  cis_dat38 <- data.frame(cis38)[c("seqnames","start","end")]
  names(cis_dat38) <- c("chr38","start38","end38")
  write.table(data.frame(cis_dat,cis_dat38),file="cis.dat",quote=FALSE,row.names=FALSE,sep="\t")
  test <- function()
  {
    library(gwascat)
    cur = makeCurrentGwascat()  # result varies by day
    data(cur)
    cur
    library(rtracklayer)
    path = system.file(package="liftOver", "extdata", "hg38ToHg19.over.chain")
    ch = import.chain(path)
    ch
    seqlevelsStyle(cur) = "UCSC"  # necessary
    cur19 = liftOver(cur, ch)
    class(cur19)
  }
END

export GTEx_v8=~/rds/public_databases/GTEx/GTEx_Analysis_v8_eQTL_cis_associations
export ext=.v8.EUR.signif_pairs.txt.gz
export M=1e6
export nlines=60
(
  parallel -C' ' --env GTEx_v8 --env ext --env M '
    read SNP hgnc ensGene pos chrpos < <(awk -v row={1} "NR==row{print \$4,\$7,\$8,\$13,\$11\"_\"\$13}" cis.dat)
    zgrep ${ensGene} ${GTEx_v8}/{2}${ext} | \
    awk -v M=${M} -v bp=${pos} -v OFS="\t" "{
       split(\$2,a,\"_\");
       chr=a[1];pos=a[2];a1=a[3];a2=a[4];
       if(a[3]<a[4]) {a1=a[3];a2=a[4]} else {a1=a[4];a2=a[3]}
       \$2=chr\":\"pos\"_\"a1\"_\"a2;
       if(bp>=a[2]-M && bp<a[2]+M) print \$1,\$2,\$12
     }" | \
    sort -k3,3g | \
    awk -vSNP=${SNP} -vensGene=${ensGene} -vtissue={2} -vOFS="\t" "NR==1 {print SNP,ensGene,tissue,\$0}"
  ' ::: $(seq 2 ${nlines}) ::: $(ls ${GTEx_v8} | grep -v egenes | xargs -l basename -s ${ext})
) > eQTL_GTEx.dat

for SNP in $(cut -f1 eQTL_GTEx.dat | uniq)
do
(
  echo ${SNP}
  awk -vSNP=${SNP} '$1==SNP' eQTL_GTEx.dat | cut -f5 | uniq
) > ${SNP}.snps
plink --bfile INTERVAL/cardio/INTERVAL --extract ${SNP}.snps --r2 inter-chr --out ${SNP}
done
