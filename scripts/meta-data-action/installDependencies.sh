#!/bin/bash
org="$1" | tr -d ' '
echo "fileNames org: $org"

# determine which organism .bridge file needs to be downloaded
FILENAMES="fileNames.config"
NAMES=$(cat $FILENAMES)
for NAME in $NAMES
do
	organismName="${NAME%=*}"
	bridgeFileName="${NAME#*=}"
	echo "organismName: $organismName"
	if [[ $org == $organismName ]]; then
		requiredFile=$bridgeFileName
    fi
	if [[ "Metabolites" == $organismName ]]; then
		metabolitesFile=$bridgeFileName
    fi
done
echo "requiredFile: $requiredFile"

# iterate through each line in fileDownloads.config and download from the URLs
FILEDOWNLOADS="fileDownloads.config"
DOWNLOADS=$(cat $FILEDOWNLOADS)
for LINK in $DOWNLOADS
do
	bridgeFile="${LINK%%=*}"
	downloadURL="${LINK#*=}"
	if [[ $requiredFile == $bridgeFile ]]; then
		echo "$requiredFile"
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

