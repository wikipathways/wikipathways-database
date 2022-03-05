## Make wpid_keep_list.txt from Analysis Collection tag.
## Useful for defining the WPIDs to maintain in this new database while
## curation is still occurring on the old database.

library(rWikiPathways)
library(dplyr)

approved_wpid <- getPathwayIdsByCurationTag("Curation:AnalysisCollection")
# write(paste(approved_wpid, collapse = "\n"), file = file.path("..","wpid_keep_list.txt"))


## compare to wikipathways-database/pathways/WPID folders:
wpid.dirs <- list.files("../pathways")

print("Approved pathways missing from repo:")
setdiff(approved_wpid, wpid.dirs)

print("Repo folders of non-approved pathways:")
setdiff(wpid.dirs,approved_wpid)

## compare to wikipathways.github.io/_pathways/WPID.md files:
wpid.mds <- list.files("_pathways")
wpid.mds <- sapply(wpid.mds, function(w){
  str_split(w, "\\.")[[1]][1]
})

print("Approved pathways missing from repo:")
setdiff(approved_wpid, wpid.mds)

print("Repo folders of non-approved pathways:")
setdiff(wpid.mds,approved_wpid)

## remove non-approved md and tsv files
wpid.rm <- setdiff(wpid.mds,approved_wpid)
lapply(wpid.rm, function(w){
  fn <- file.path("_pathways",paste(w,"md",sep = "."))
  if (file.exists(fn)) {
    file.remove(fn)
  }
  fn1 <- file.path("_data",paste0(w,"-bibliography.tsv"))
  if (file.exists(fn1)) {
    file.remove(fn1)
  }
  fn2 <- file.path("_data",paste0(w,"-datanodes.tsv"))
  if (file.exists(fn2)) {
    file.remove(fn2)
  }
})
