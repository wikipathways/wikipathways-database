#' Update Cited In
#'
#' Reads a TSV file with two columns, with a PubMed Central identifier or DOI 
#' in the second column, publication title in the third, and WPIDs
#' (and "WikiPathways") in the first.
#' Compiles the resulting PMCIDs and updates a citedin.yml file. The last_run
#' date is also stored to be used in subsequent updates.

library(yaml)
library(readr)

updateCitedIn <- function(){
  input.path = './downstream/citedin_input.tsv'
  ci.path = './downstream/citedin_lookup.yml'
  ci.yml = yaml::read_yaml(ci.path)

  input.data = read_tsv(input.path, col_types="ccc")
  for(i in 1:nrow(input.data)) {
    row = input.data[i,];
    wpid <- row$"WPID";
    pubid <- row$"PubID";
    pubtitle <- row$"Title";
    novel.yml <- list()
    novel.yml <- append(novel.yml, list(link=pubid, title=pubtitle))
    ci.yml[[wpid]] <- append(ci.yml[[wpid]],list(novel.yml))
  }

  ci.yml$last_run = format(Sys.time(), "%Y/%m/%d")
  ci.yml <- ci.yml[sort(names(ci.yml))] #keep sorted
  write("---", ci.path, append = F)
  write(yaml::as.yaml(ci.yml), ci.path, append = T)
  write("---", ci.path, append = T)
}

# Run the function when called by GH Action:
updateCitedIn()
