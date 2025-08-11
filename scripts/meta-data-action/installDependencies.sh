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
set -euo pipefail

FILEDOWNLOADS="fileDownloads.config"
ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
ref="https://figshare.com/"

download_bridge() {
  target="$1"
  url="$2"
  norm="${url/https:\/\/figshare.com\/ndownloader/https:\/\/ndownloader.figshare.com}"

  if [ -s "$target" ] && unzip -t "$target" >/dev/null 2>&1; then
    echo "OK: $target already valid"
    return 0
  fi

  tmp="$(mktemp)"
  attempts=10
  delay=2
  i=1
  while :; do
    echo "wget $norm -> $target (attempt $i/$attempts)"
    if wget --quiet --progress=dot:giga \
            --user-agent="$ua" --header="Referer: $ref" \
            --tries=5 --waitretry=2 --retry-connrefused \
            --retry-on-http-error=403,429,500,502,503,504 \
            -O "$tmp" "$norm"; then
      if unzip -t "$tmp" >/dev/null 2>&1; then
        mv -f "$tmp" "$target"
        echo "Saved $target"
        return 0
      else
        echo "Downloaded file failed zip test; retrying"
      fi
    else
      echo "wget failed; retrying"
    fi
    if [ "$i" -ge "$attempts" ]; then
      rm -f "$tmp"
      echo "Failed to download a valid $target after $attempts attempts"
      return 1
    fi
    sleep "$delay"
    delay=$((delay * 2))
    i=$((i + 1))
  done
}

while IFS= read -r line || [ -n "$line" ]; do
  [ -z "${line##\#*}" ] && continue
  [ -z "$line" ] && continue
  bridgeFile="${line%%=*}"
  downloadURL="${line#*=}"

  if [ "$bridgeFile" = "${requiredFile:-}" ] || [ "$bridgeFile" = "${metabolitesFile:-}" ]; then
    if [ ! -e "./$bridgeFile" ] || ! unzip -t "./$bridgeFile" >/dev/null 2>&1; then
      download_bridge "$bridgeFile" "$downloadURL"
    else
      echo "Skipping existing valid $bridgeFile"
    fi
  fi
done < "$FILEDOWNLOADS"
