#!/bin/bash
# pass organism in as argument
ORGANISM="$1"

echo organism:
ORGANISM=`echo $ORGANISM | sed -e 's/^[[:space:]]*//'`
echo "$ORGANISM"

wget -O gene.json https://www.bridgedb.org/data/gene.json
wget -O other.json https://www.bridgedb.org/data/other.json

# generate fileNames.config and fileDownloads.config with species + file name, species + download URL
# these files will be used in the installDependencies bash script

jq -r '.mappingFiles | .[] | "\(.species)=\(.file)"' gene.json | tr -d ' ' > fileNames.config
jq -r '.mappingFiles | .[] | "\(.type)=\(.file)"' other.json | tr -d ' ' >> fileNames.config

jq -r '.mappingFiles | .[] | "\(.file)=\(.downloadURL)"' gene.json | tr -d ' ' > fileDownloads.config
jq -r '.mappingFiles | .[] | "\(.file)=\(.downloadURL)"' other.json | tr -d ' ' >> fileDownloads.config


ORGANISM="$ORGANISM" jq -n 'env.ORGANISM'

speciesURL=$(jq -r --arg ORGANISM "$ORGANISM" '
        .mappingFiles[]
        | select(.species==$ORGANISM) 
        | .downloadURL' gene.json)

metabolitesURL=$(jq -r --arg ORGANISM "$ORGANISM" '
        .mappingFiles[]
        | select(.type=="Metabolites") 
        | .downloadURL' other.json)
		
speciesFilename=$(jq -r --arg ORGANISM "$ORGANISM" '
        .mappingFiles[]
        | select(.species==$ORGANISM) 
        | .file' gene.json)

metabolitesFilename=$(jq -r --arg ORGANISM "$ORGANISM" '
        .mappingFiles[]
        | select(.type=="Metabolites") 
        | .file' other.json)
		
echo speciesURL:
echo "$speciesURL" 

echo speciesFilename:
echo "$speciesFilename"

echo metabolitesURL:
echo "$metabolitesURL"

echo metabolitesFilename:
echo "$metabolitesFilename"

#create gdb.config file with correct filename
CFG_FILE="gdb.config"

function make_config() {
     echo -n "" > $CFG_FILE
	 echo "$ORGANISM	$speciesFilename" >> $CFG_FILE;
	 echo "*	$metabolitesFilename" >> $CFG_FILE;
}

make_config
