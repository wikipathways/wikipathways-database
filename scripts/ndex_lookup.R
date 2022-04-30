# create table of WPIDs and NDEX UUIDs to support links and scripting use cases

library(dplyr)
library(stringr)
BiocManager::install("ndexr")
library(ndexr)
install.packages("keyringr")
library("keyringr")

# get network summaries for all wikipathways content
ndexcon<-ndex_connect('wikipathways', keyringr::decrypt_kc_pw("ndex_wikipathways")) #requires prior entry of credentials into keychain
ndex.netsum<-ndex_user_get_networksummary(ndexcon, '363f49e0-4cf0-11e9-9f06-0ac135e8bacf')

# filter for WPID pathways
ndex.netsum.sub<-dplyr::select(ndex.netsum,c(name,externalId))
ndex.netsum.sub<-dplyr::filter(ndex.netsum.sub, substr(name,1,2) == "WP")
ndex.netsum.sub<-dplyr::mutate(ndex.netsum.sub,name=str_match(name, "WP\\d+"))
names(ndex.netsum.sub) <- c("wpid", "ndexid")  

# write to _data dir
write.table(ndex.netsum.sub, "../downstream/ndex_lookup.csv", sep = ",",
            row.names = F, col.names = T)