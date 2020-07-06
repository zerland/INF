#!/usr/bin/bash

cd work
cut -f5 INF1.merge | \
sed '1d' | \
uniq | \
grep -f - -v inf1.tmp > INF1.merge.nosig
R --no-save <<END
  rle.plot <- function()
# RLE plot
  {
    groups <- rep(1,nrow(df))
    groups[rownames(df)%in%nosig] <-2
    col.groups=c("black","red")
    makeRLEplot(df, log2.data=FALSE, groups=groups, col.group=col.groups, cex=0.3, showTitle=TRUE)
  }
  box.plot <- function(df)
# Box-Whisker plot
  {
    np <- ncol(df)
    cols <- rep("black",np)
    cols[colnames(df)%in%nosig$prot] <- "red"
    boxplot(df,cex=0.2,horizontal=TRUE,line=1,las=1,cex.axis=0.25,col=cols,tck=-0.2)
  }
  library(gap)
  qc_inf <- read.csv("olink_proteomics/qc/olink_qc_inf.csv",as.is=TRUE)
  names(qc_inf) <- toupper(names(qc_inf))
  qc <- qc_inf[setdiff(names(qc_inf),"P23560")]
  tqc <- t(qc[,-(1:2)])
  nosig <-read.table("INF1.merge.nosig",as.is=TRUE,col.names=c("prot","uniprot"))
  pdf("qc.pdf")
  df <- qc[,-(1:2)]
  ndf <- names(df)
  odf <- order(ndf)
  df <- df[ndf[odf]]
  inf <- subset(inf1,uniprot!="P23560")
  ord <- with(inf,order(uniprot))
  names(df) <- inf[ord,"prot"]
  box.plot(df)
  dev.off()
# summary statistics
  m <- apply(qc[,-(1:2)],2,mean,na.rm=TRUE)
  s <- apply(qc[,-(1:2)],2,sd,na.rm=TRUE)
  ms <- t(rbind(m,s))
  abundance <- data.frame(uniprot=rownames(ms),ms)
  d <- within(merge(inf1,abundance,by="uniprot"),{nosig <- FALSE})
  d[d$uniprot%in%nosig$uniprot,"nosig"] <- TRUE
  d
END
cd -
