#!/usr/bin/bash

#SBATCH --job-name=IL.17C
#SBATCH --account CARDIO-SL0-CPU
#SBATCH --partition cardio
#SBATCH --qos=cardio
#SBATCH --time=1-00:00:00
#SBATCH --output=/rds/user/jhz22/hpc-work/work/%A_%a.out
#SBATCH --error=/rds/user/jhz22/hpc-work/work/%A_%a.err
#SBATCH --export ALL

function setup()
# IL.17C
{
tabix sumstats/INTERVAL/INTERVAL.TRAIL.gz 16 | sort -k11,11gr | awk '$11!="NA"' | tail
# chr16:85703851_C_G rs530452211 GSE1
# chr16:54261627_A_G rs12933399 RP11-324D17.1
# chr16:61477410_G_GTA rs567557033 CDH8
# chr16:88684495_G_T rs17700884 

vep --id "16 85703851 85703851 C/G" --species homo_sapiens --assembly GRCh37 -o rs530452211 --cache --offline --force_overwrite --tab \
                                    --nearest symbol --pick
vep --id "16 54261627 54261627 A/G" --species homo_sapiens --assembly GRCh37 -o rs12933399 --cache --offline --force_overwrite --tab \
                                    --nearest symbol --pick
vep --id "16 61477410 61477410 G/GTA" --species homo_sapiens --assembly GRCh37 -o rs567557033 --cache --offline --force_overwrite --tab \
                                      --nearest symbol --pick
vep --id "16 88684495 88684495 G/T" --species homo_sapiens --assembly GRCh37 -o rs17700884 --cache --offline --force_overwrite --tab \
                                    --nearest symbol --pick
gunzip -c ${INF}/sumstats/INTERVAL/INTERVAL.IL.17C.gz | cut -f1-3,9-10 | gzip -f > ${INF}/work/IL.17C.gz

Rscript -e '
  suppressMessages(library(dplyr))
  suppressMessages(library(gap))
  INF <- Sys.getenv("INF")
  genes <- data.frame(MarkerName=c("chr16:88684495_G_T"),gene=c("IL17C"),color=c("red"))
  gz <- gzfile(file.path(INF,"work","IL.17C.gz"))
  IL.17C <- read.delim(gz,as.is=TRUE) %>%
            mutate(Z=BETA/SE,P=pvalue(Z),log10P=-log10p(Z)) %>%
            rename(Chromosome=CHR,Position=POS,MarkerName=SNPID) %>%
            select(Chromosome,Position,MarkerName,Z,P,log10P) %>%
            left_join(genes)
  save(IL.17C, genes, file=file.path(INF,"work","IL.17C.rda"))
'
}

Rscript -e '
  suppressMessages(library(dplyr))
  suppressMessages(library(gap))
  INF <- Sys.getenv("INF")
  load(file.path(INF,"work","IL.17C.rda"))
  subset(IL.17C,!is.na(gene))
  png("IL.17C-mhtplot.trunc.png", res=300, units="in", width=9, height=6)
  par(oma=c(0,0,0,0), mar=c(5,6.5,1,1))
  mhtplot.trunc(subset(IL.17C,!is.na(Z),select=-color), chr="Chromosome", bp="Position", z="Z", snp="MarkerName",
                suggestiveline=-log10(1e-7), genomewideline=-log10(5e-10),
                cex.mtext=1.2, cex.text=0.7,
                annotatelog10P=-log10(1.1e-6), annotateTop = FALSE, highlight=with(genes,gene),
                mtext.line=3, y.brk1=0.1, y.brk2=0.5, trunc.yaxis=FALSE, delta=0.01, cex.axis=1.2,
                cex=0.5, font=2, font.axis=1,
                y.ax.space=20,
                col = c("blue4", "skyblue")
  )
  dev.off()
  mhtdata <- filter(IL.17C,!is.na(Z)) %>%
             select(-MarkerName,-Z,-log10P) %>%
             mutate(P=as.numeric(P))
  cis <- with(mhtdata,Chromosome==16 & Position>=88704999-1e6 & Position<=88706881+1e6)
  mhtdata[cis,"color"] <- "red"
  subset(mhtdata,!is.na(gene))
  png("IL.17C-mhtplot2.png", res=300, units="in", width=9, height=6)
  opar <- par()
  par(cex=0.5)
  ops <- mht.control(colors=rep(c("blue4","skyblue"),11),srt=0,yline=2.5,xline=2)
  hops <- hmht.control(data=subset(mhtdata,!is.na(gene)))
  mhtplot2(mhtdata,ops,hops,xlab="",ylab="",srt=0, cex.axis=1.2)
  axis(2,at=1:8)
  title("")
  par(opar)
  dev.off()
'

R --no-save -q <<END
# 24/9/2020, not highlighted
  library(gap)
# library(Rmpfr)
  INF <- Sys.getenv("INF")
  gz <- gzfile(file.path(INF,"METAL","IL.17C-1.tbl.gz"))
  IL.17C <- within(read.delim(gz,as.is=TRUE), {
   Z <- Effect/StdErr;
#  P <- as.numeric(2*pnorm(mpfr(abs(Z),100),lower.tail=FALSE))
   P <- 2*pnorm(abs(Z),lower.tail=FALSE)
  })
  subset(IL.17C, P==0)
  png("IL.17C.png", res=300, units="in", width=9, height=6)
  par(oma=c(0,0,0,0), mar=c(5,6.5,1,1))
  mhtplot.trunc(IL.17C, chr="Chromosome", bp="Position", p="P", snp="MarkerName", z = "Z",
                suggestiveline=FALSE, genomewideline=-log10(5e-10), logp = TRUE,
                cex.mtext=0.6, cex.text=0.7,
                mtext.line=4, y.brk1=300, y.brk2=500, cex.axis=0.6, cex=0.5,
                y.ax.space=20,
                col = c("blue4", "skyblue")
  )
  dev.off()
END
