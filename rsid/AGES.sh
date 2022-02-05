#!/usr/bin/bash

if [ ! -d ${INF}/AGES ]; then mkdir ${INF}/AGES; fi
cd ${INF}/AGES

export stables=https://static-content.springer.com/esm/art%3A10.1038%2Fs41467-021-27850-z/MediaObjects/41467_2021_27850_MOESM18_ESM.xlsx

function download()
{
R --no-save <<END
  INF <- Sys.getenv("INF")
  stables <- Sys.getenv("stables")
  st16 <- openxlsx::read.xlsx(stables, sheet=1, colNames=TRUE, skipEmptyRows=TRUE, startRow=3)
  write.table(st16,file="AGES.txt",col.names=FALSE,quote=FALSE,row.names=FALSE,sep="\t")
  suppressMessages(library(dplyr))
  https <- "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/GCST90086001-GCST90087000"
  urls <- mutate(st16, tag=gsub("_",".",Study.tag),trait=gsub("Serum levels of protein ","",Reported.trait),
                 SOMAMER_ID=paste0(trait,".",tag)) %>%
          left_join(pQTLtools::SomaLogic160410) %>%
          select(Study.Accession,Summary.statistics.file,SOMAMER_ID,UniProt,Target) %>%
          filter(UniProt %in% pQTLtools::inf1$uniprot) %>%
          distinct() %>%
          mutate(src=file.path(https,Study.Accession,paste0(Study.Accession,"_buildGRCh37.tsv")),cmd=paste("wget",src))
  write.table(select(urls,cmd),file=file.path(INF,"AGES","wget.sh"),quote=FALSE,col.names=FALSE,row.names=FALSE)
END

# write.table(pQTLtools::inf1[c("prot","target.short")],file="INF1.prot",quote=FALSE,row.names=FALSE,col.names=FALSE)

(
  gunzip -c ~/rds/results/public/proteomics/scallop-cvd1/*txt.gz | \
  head -1 | \
  awk -vOFS="\t" '{print "Protein",$0}'
  join <(cut -f5,6 ${INF}/work/INF1.merge | sed '1d' | sort -k1,1) \
       <(grep -v BDNF ${INF}/cvd1/INF1.prot | sort -k1,1 ) | \
  sed 's/VEGF_A/VEGF-A/;s/MIP.1.alpha/CCL3/;s/MIP-1 alpha/CCL3/' | \
  sort -k3,3 | \
  join -13 - ${INF}/cvd1/inf.txt | \
  cut -d' ' -f2 --complement | \
  sed 's/chr//;s/_/:/' | \
  parallel -j8 -C' ' '
    echo {1}-{2}
    zgrep -w {2} ~/rds/results/public/proteomics/scallop-cvd1/{1}.txt.gz;
    awk -vOFS="\t" -vprot={1} "{print prot,\$0}"
  '
) > ${INF}/cvd1/INF1.merge.replication.txt

# snpid --> rsid
sed 's/chr//;s/_/:/' ${INF}/work/INF1.merge.rsid > ${INF}/cvd1/INF1.merge.rsid
for f in INF1.merge.replication.txt
do
  awk -vOFS="\t" '{if(NF==1) printf $1 OFS; else print}' ${f} > ${f}-rsid
  (
  cat ${INF}/cvd1/INF1.merge.rsid | \
  parallel --dry-run -C' ' "
    export s={1};
    export r={2};
    sed -i 's/'\"\${s}\"'/'\"\${r}\"'/' ${f}-rsid
  "
  ) | bash
done
awk -vOFS="\t" '{if(NR>1) {split($1,a,"-");$1=a[1]};print}' INF1.merge.replication.txt-rsid | xsel -i
awk -vOFS='\t' '
{
  if (NR>1) {
    sub(/-rs/," rs",$1)
    gsub(/:/,"_",$2);$2="chr"$2
    $3=toupper($3)
    $4=toupper($4)
  }
  if (NR==1 || $9 <= 5e-8) print
}
' INF1.merge.replication.txt-rsid | \
cut -f10,11 --complement > INF1.cvd1.replication

(
  head -1 INF1.cvd1.replication
  sed '1d' INF1.cvd1.replication | \
  sort -k1,1 -k2,2
) > INF1.cvd1.txt
rm INF1.cvd1.replication

for p in 5e-8 1e-5 5e-2
do
  echo ${p}
  cut -f9 ${INF}/cvd1/INF1.merge.replication.txt-rsid | awk -v p=${p} '$1<p{print $1}' | wc -l
done
cd -

R --no-save -q <<END
  library(dplyr)
  INF <- Sys.getenv("INF")
  INF1_METAL <- read.delim(file.path(INF,"work","INF1.METAL")) %>%
                mutate(Allele1=toupper(Allele1), Allele2=toupper(Allele2))
  cvd1 <- read.delim(file.path(INF,"cvd1","INF1.merge.replication.txt-rsid")) %>%
          rename(A1=Allele1,A2=Allele2,CODE_ALL_FQ=Freq1,BETA=Effect,SE=StdErr) %>%
          mutate(A1=toupper(A1),A2=toupper(A2),MarkerName=paste0("chr",sub("(\\:.*?)\\:", "\\1_",MarkerName))) %>%
          select(-MarkerName,-Direction)
  INF1_cvd1 <- INF1_METAL %>%
               left_join(gap::inf1[c("prot","target.short")]) %>%
               mutate(Protein=paste0(target.short,"-",rsid)) %>%
               left_join(cvd1) %>%
               select(Protein,Allele1,Allele2,A1,A2,Freq1,Effect,StdErr,CODE_ALL_FQ,BETA,SE,cis.trans) %>%
               mutate(sw=if_else(Allele1==A2,-1,1)) %>%
               mutate(BETA=sw*BETA)
  filter(INF1_cvd1,!is.na(BETA))
  all <- INF1_cvd1 %>%
         filter(!is.na(BETA)) %>%
         select(Effect,BETA)
  cor(all,use="everything")
  cis <- INF1_cvd1 %>%
         filter(!is.na(BETA) & cis.trans=="cis") %>%
         select(Effect,BETA)
  cor(cis,use="everything")
  trans <- INF1_cvd1 %>%
           filter(!is.na(BETA) & cis.trans=="trans") %>%
           select(Effect,BETA)
  cor(trans,use="everything")
END

## obsolete

function st2()
{
R --no-save <<END
  options(width=200)
  stables <- Sys.getenv("stables")
  st1 <- openxlsx::read.xlsx(stables, sheet=1, colNames=TRUE, skipEmptyRows=TRUE, cols=c(1:23), rows=c(3:95))
  st2 <- openxlsx::read.xlsx(stables, sheet=2, colNames=TRUE, skipEmptyRows=TRUE, cols=c(1:33), rows=c(2:547))
  library(dplyr)
  st1_INF <- filter(st1,INFI=="Y")
  st2_INF <- filter(st2,Protein%in%st1_INF$Short_annotation) %>%
             select(Protein,MarkerName,"rs-id",A1,A2,Effect,StdErr,"Freq.(A1)","Cis/Trans.(1.MB)") %>%
             rename(st2_rsid="rs-id",st2_cistrans="Cis/Trans.(1.MB)",BETA=Effect,SE=StdErr,CODE_ALL_FQ="Freq.(A1)") %>%
             mutate(st2_Protein=paste0(Protein,"-",st2_rsid),MarkerName=paste0("chr",sub("(\\:.*?)\\:", "\\1_",MarkerName))) %>%
             select(-Protein)
  INF <- Sys.getenv("INF")
  INF1_METAL <- read.delim(file.path(INF,"work","INF1.METAL")) %>%
                mutate(Allele1=toupper(Allele1), Allele2=toupper(Allele2)) %>%
                left_join(gap::inf1[c("prot","target.short")],by="prot") %>%
                mutate(Protein=paste0(target.short,"-",rsid)) %>%
                select(-prot,-target.short,-rsid)
  INF1_CVD1 <- INF1_METAL %>%
               left_join(st2_INF) %>%
               select(Protein,Allele1,Allele2,A1,A2,Freq1,Effect,StdErr,CODE_ALL_FQ,BETA,SE,cis.trans) %>%
               mutate(sw=if_else(Allele1==A2,-1,1)) %>%
               mutate(BETA=sw*BETA)
END
}

