#' Update Cited In
#'
#' Queries PubMed Central for WPIDs (and "WikiPathways") in full text artcles.
#' Compiles the resulting PMCIDs and updates a citedin.yml file. The last_run
#' date is also stored to be used in subsequent updates.
#' 
#' @param from_date (String) the oldest publication date to search. If left 
#' NULL, then the last_run date is used. Format: YYYY/MM/DD (e.g.,'2008/01/01')
#'
#' @details With a rate limit of one query per second for eutils API, this
#' function takes ~2000 seconds (or 33 min) for 2000 pathways. Should be run
#' quarterly or even annually for best ROI.

library(rvest)
library(xml2)
library(dplyr)
library(magrittr)
library(RJSONIO)
library(yaml)
library(httr)

updateCitedIn<-function(from_date=NULL){
  ci.path = './downstream/citedin_lookup.yml'  
  ci.yml = yaml::read_yaml(ci.path)
  
  if(is.null(from_date))
    from_date = ci.yml$last_run

  wpid.list = list.dirs("./pathways",FALSE,FALSE)
  for (p in wpid.list){
    q = paste0('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pmc&term=wikipathways+AND+',
               p,'+AND+(',from_date,'[pdat]:3000[pdat])&retmode=json')
    res <- httr::GET(url=URLencode(q), config = httr::config(connecttimeout = 60))
    res.char <- rawToChar(res$content)
    res.json <- RJSONIO::fromJSON(res.char)
    ids <- list()
    if (!is.null(res.json))
      if (!is.null(res.json$esearchresult))
        ids <- res.json$esearchresult$idlist
    ids.len <- length(ids)
    cat(sprintf("%s cited in %i articles\n", p,ids.len ))
    if(ids.len > 0){
      pmcids <- lapply(ids, function(id) list(link=paste0("PMC",id)))
      novel.pmcids <- setdiff(unlist(pmcids),unlist(ci.yml[[p]]))
      if(length(novel.pmcids) > 0){
        novel.yml <- list()
        for (n in novel.pmcids){
          # collect metadata
          md.query <- paste0("https://www.ncbi.nlm.nih.gov/pmc/oai/oai.cgi?verb=GetRecord&identifier=oai:pubmedcentral.nih.gov:",gsub("PMC","", n),"&metadataPrefix=pmc_fm")
          md.source <- xml2::read_html(md.query,
                                       options = c("RECOVER", "NOERROR")) 
          year <- md.source %>%
            rvest::html_node(xpath=".//year") %>%
            rvest::html_text()
          article_title <- md.source %>%
            rvest::html_node(xpath=".//article-title") %>%
            rvest::html_text()
          t <- paste0(article_title, " (",year,")")
          novel.yml <- append(novel.yml, list(link=n, title=t))
          Sys.sleep(1) #API rate limit
        }
        ci.yml[[p]] <- append(ci.yml[[p]],list(novel.yml))
      }
    }
    Sys.sleep(1) #API rate limit
  }
  
  ci.yml$last_run = format(Sys.time(), "%Y/%m/%d")
  write("---", ci.path, append = F)
  write(yaml::as.yaml(ci.yml), ci.path, append = T)
  write("---", ci.path, append = T)

}
                       
# Run the function when called by GH Action:
updateCitedIn()
