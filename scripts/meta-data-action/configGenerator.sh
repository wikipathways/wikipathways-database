#!/bin/bash
# pass wp file in as argument
wpFile="$1"

ORGANISM=""
FILENAME=""
ORGANISM="$(sed -n '/<Pathway /s/.*Organism=\(.*\)[^\n]*/\1/p' $wpFile | tr -d '"' | tr -d '>' | tr -d '\r')"            
            
org="$(sed -n '/<Pathway /s/.*Organism=\(.*\)[^\n]*/\1/p' $wpFile | tr -d '"' | tr -d '>' | tr -d '\r'| tr -d ' ')"
echo "adding organism $org to changedSpecies list"
changedSpecies+=("$org")
echo "$changedSpecies"


echo organism:
ORGANISM=`echo $ORGANISM | sed -e 's/^[[:space:]]*//'`
echo "$ORGANISM"

wget https://bridgedb.github.io/data/gene.json
wget https://bridgedb.github.io/data/other.json

# generate fileNames.config and fileDownloads.config with species + file name, species + download URL
# these files will be used in the installDependencies bash script

jq -r '.mappingFiles | .[] | "\(.species)=\(.file)"' gene.json | tr -d ' ' > fileNames.config
jq -r '.mappingFiles | .[2] | "\(.type)=\(.file)"' other.json | tr -d ' ' >> fileNames.config

jq -r '.mappingFiles | .[] | "\(.file)=\(.downloadURL)"' gene.json | tr -d ' ' > fileDownloads.config
jq -r '.mappingFiles | .[2] | "\(.file)=\(.downloadURL)"' other.json | tr -d ' ' >> fileDownloads.config


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

wpid=$(basename ""$wpFile"" | sed 's/.gpml//')
echo "$wpid"
echo "$wpFile"

#create gdb.config file with correct filename
CFG_FILE="gdb.config"

function make_config() {
     echo -n "" > $CFG_FILE
	 echo "$ORGANISM	$speciesFilename" >> $CFG_FILE;
	 echo "*	$metabolitesFilename" >> $CFG_FILE;
}

make_config