#' Update Cited In
#'
#' Queries PubMed Central for WPIDs (and "WikiPathways") in full text artcles.
#' Compiles the resulting PMCIDs and updates a citedin.yml file. The last_run
#' date is also stored to be used in subsequent updates.
#' 
#' @param from_date (String) the oldest publication date to search. If left 
#' NULL, then the last_run date is used. Format: MM/DD/YYYY (e.g.,'01/01/2008')
#'
#' @details With a rate limit of one query per second for eutils API, this
#' function takes ~2000 seconds (or 33 min) for 2000 pathways. Should be run
#' quarterly or even annually for best ROI.
#' 
#' @return writes to citedin.yml
#' @importFrom RJSONIO fromJSON
#' @importFrom utils URLencode
#' @importFrom httr GET
#' @importFrom yaml read_yaml write_yaml
#' @export
#'
#' @examples
updateCitedIn<-function(from_date=NULL){
  ci.path = '../downstream/citedin_lookup.yml'  
  ci.yml = yaml::read_yaml(ci.path)
  
  if(is.null(from_date))
    from_date = ci.yml$last_run

  wpid.list = read.table('../wpid_list.txt', header = F, stringsAsFactors = F)
  for (p in wpid.list[,1]){
    q = paste0('https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pmc&term=wikipathways+AND+',
               p,'+AND+(',from_date,'[pdat]:3000[pdat])&retmode=json')
    res <- GET(url=URLencode(q))
    res.char <- rawToChar(res$content)
    res.json <- RJSONIO::fromJSON(res.char)
    ids <- res.json$esearchresult$idlist
    ids.len <- length(ids)
    cat(sprintf("%s cited in %i articles\n", p,ids.len ))
    if(ids.len > 0){
      pmcids <- lapply(ids, function(id) list(link=paste0("PMC",id)))
      novel.pmcids <- setdiff(unlist(pmcids),unlist(ci.yml[[p]]))
      if(length(novel.pmcids) > 0)
        ci.yml[[p]] <- append(ci.yml[[p]],pmcids)
    }
    Sys.sleep(1) #API rate limit
  }
  
  ci.yml$last_run = format(Sys.time(), "%m/%d/%Y")
  yaml::write_yaml('---', ci.path)
  yaml::write_yaml(ci.yml, ci.path)
  yaml::write_yaml('---', ci.path)
  
}
