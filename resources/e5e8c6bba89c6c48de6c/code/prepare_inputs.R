args <- commandArgs(TRUE)
stopifnot(length(args)==1)
base <- normalizePath(args[1])
project <- dirname(dirname(base))
case <- function(i) file.path(project,"biofigure/benchmark/library/topjournal",paste0("issue_",i))
sbs_groups <- c("C>A","C>G","C>T","T>A","T>C","T>G")
dbs_groups <- c("AC","AT","CC","CG","CT","GC","TA","TC","TG","TT")
spectrum <- function(kind, signature, groups) {
  f <- file.path(base,"issue_081",sprintf("COSMIC_v3.4_%s_GRCh37.txt",kind))
  x <- read.delim(f, check.names=FALSE)
  context <- x$Type
  group <- if (kind=="SBS") sub("^.\\[(...)\\].$","\\1",context) else sub(">.*$","",context)
  label <- if (kind=="SBS") paste0(substr(context,1,1), substr(context,nchar(context),nchar(context))) else sub(".*>","",context)
  # Channel ordering is biological, rather than the order of physical TSV rows.
  order_key <- if (kind=="SBS") paste0(substr(context,1,1),substr(context,nchar(context),nchar(context))) else context
  o <- order(match(group,groups),order_key)
  data.frame(signature=signature,channel=context[o],label=label[o],group=group[o],rank=seq_along(o),
             fraction=x[[signature]][o])
}
profile <- rbind(spectrum("SBS","SBS4",sbs_groups),spectrum("DBS","DBS2",dbs_groups))
stopifnot(nrow(profile)==174L, all(abs(tapply(profile$fraction,profile$signature,sum)-1)<1e-6))
readr::write_csv(profile,file.path(case("081"),"plot_data/signatures.csv"))

set.seed(871116L)
n <- 50L
term <- sprintf("Set %02d",seq_len(n))
named <- c("KRAS signaling DN","IFN-alpha response","Oxidative metabolism","UV response DN",
           "EMT","MYC targets","G2M checkpoint","E2F targets")
key <- c(1,3,8,33,39,44,48,50)
term[key] <- named
nes <- c(seq(2.15,.61,length.out=20),seq(-.6,-2.23,length.out=30)) + rnorm(n,0,.028)
gene_sets <- data.frame(term, NES=round(nes,4), size=sample(35:190,n),
                        p_adj=10^-round(runif(n,0.1,2)+3.1*abs(nes),3), label=seq_len(n)%in%key)
readr::write_csv(gene_sets[sample(n),],file.path(case("087"),"plot_data/ranked-enrichment.csv"))

set.seed(941116L)
n <- 108L
data <- data.frame(id=sprintf("P%03d",seq_len(n)),
  age=sample(21:75,n,replace=TRUE),
  BMI=round(pmin(41,pmax(15,rnorm(n,25.9,4.5))),1),
  Gender=sample(rep(c("Female","Male"),c(60,48))),
  Ethnicity=sample(rep(c("Asian","Black","Caucasian","Hispanic","Unknown"),c(22,14,56,12,4))),
  IRIS=sample(rep(c("IS","IR","Unknown"),c(60,41,7))))
readr::write_csv(data[sample(n),],file.path(case("094"),"plot_data/circular-cohort.csv"))
