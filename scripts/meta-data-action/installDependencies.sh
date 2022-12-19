#!/bin/bash
org="$1" 
org=`echo $org | tr -d ' '`

# determine which organism .bridge file needs to be downloaded
FILENAMES="fileNames.config"
NAMES=$(cat $FILENAMES)
for NAME in $NAMES
do
	organismName="${NAME%=*}"
	bridgeFileName="${NAME#*=}"
	if [[ $org == $organismName ]]; then
		requiredFile=$bridgeFileName
    fi
	if [[ "Metabolites" == $organismName ]]; then
		metabolitesFile=$bridgeFileName
    fi
done

# iterate through each line in fileDownloads.config and download from the URLs
FILEDOWNLOADS="fileDownloads.config"
DOWNLOADS=$(cat $FILEDOWNLOADS)
for LINK in $DOWNLOADS
do
	bridgeFile="${LINK%%=*}"
	downloadURL="${LINK#*=}"
	if [[ $requiredFile == $bridgeFile ]]; then
		if [ ! -e ./$bridgeFile ]; then
			echo "wget $downloadURL"
			wget -O $bridgeFile $downloadURL
		fi
	fi
	if [[ $metabolitesFile == $bridgeFile ]]; then
		if [ ! -e ./$bridgeFile ]; then
			echo "wget $downloadURL"
			wget -O $bridgeFile $downloadURL
		fi
	fi
done

