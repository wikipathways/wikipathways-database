## Make wpid_keep_list.txt from Analysis Collection tag.
## Useful for defining the WPIDs to maintain in this new database while
## curation is still occurring on the old database.

library(rWikiPathways)
library(dplyr)

approved_wpid <- getPathwayIdsByCurationTag("Curation:AnalysisCollection")
write(paste(approved_wpid, collapse = "\n"), file = file.path("..","wpid_keep_list.txt"))


## compare to pathways/WPID folders:
wpid.dirs <- list.files("../pathways")

print("Approved pathways missing from repo:")
setdiff(approved_wpid, wpid.dirs)

print("Repo folders of non-approved pathways:")
setdiff(wpid.dirs,approved_wpid)
