#!/bin/zsh
exec >local-run.log 2>&1

# This script reproduces the on-gpml-change GH Action as a script 
# to be run locally.

###################################
echo "1. Define list of GPML files"

# 1A. Either as a local folder containing GPML files
changed_dir="local_gpml_files" #set to "" to use 1B instead

# 1B. Or as a list of WPIDs referencing GPMLs in existing pathway subfolders
changed_wpids=() #WPIDs or use keyword "ALL"

# Identify file paths to changed GPMLs; creating them if necessary.
changed_gpmls=()
if [ ! -z "$changed_dir" ]; then
    for i in "$changed_dir"/*/*.gpml; do
        this_wpid="$(basename -s .gpml $i)"
        this_dir="pathways/$this_wpid"
        if [ ! -d "$this_dir" ]; then
            mkdir -p pathways/"$this_wpid"
        fi
        new_path=$this_dir"/"$this_wpid".gpml"
        if [ -s $i ]; then #if not empty
            cp $i $new_path
            echo $new_path
            changed_gpmls+="$new_path"
        else
            echo "$i is empty. SKIP"
            if [ ! -s $new_path ]; then #clean up empty dir
                rm -rf pathways/"$this_wpid"
            fi
        fi
    done
else
    if [ -z "$changed_wpids" ]; then
        echo "Set either changed_dir or changed_wpids."
        echo "EXITING"
        exit 1;
    elif [ "${changed_wpids[1]}" = "ALL" ]; then
        for i in pathways/*/*.gpml; do
            echo "$i"
            changed_gpmls+="$i"
        done
    else 
        for i in ${changed_wpids[@]}; do
            changed_gpmls+="pathways/${i##*/}/${i##*/}.gpml"
        done
        # 1B. Or as a local folder containing GPML files
        #changed-gpmls = 

        # Verify changed GPML files:
        for i in ${changed_gpmls[@]}; do
            if [ -f $i ]; then #file exists
                if [ -s $i ]; then #file is not empty
                    echo "$i"
                else
                echo "$i is empty"'!'
                echo "EXITING"
                exit 1;
                fi
            else
                echo "$i not found"'!'
                echo "EXITING"
                exit 1;
            fi
        done
    fi
fi

echo "Identified ${#changed_gpmls[@]} changed GPML files."

##############################
echo "1B. TODO-ACTION: gpml-cleanup"

for f in ${changed_gpmls[@]}; do
    #Avoid error: org.pathvisio.libgpml.io.ConverterException: class java.lang.IllegalArgumentException: Citation must have valid xref or url, or both
    sed -i '' 's/><\/bp:ID>/>NA<\/bp:ID>/' "$f"
done


##############################
echo "2. ACTION: author-list"

authorList=() 
{
    read #skip header line
    while IFS=, read -r username realname orcid wikidata github; do
        authorList+=("$username") 
    done 
}< scripts/author_list.csv
echo ${#authorList[@]}

checkAuthors=()
for f in ${changed_gpmls[@]}; do
 auth="$(sed -n '/<Pathway /s/.*Author=\"\[\(.*\)\]\".*/\1/p' $f )"
 checkAuthors+=("${(@s:,:)auth}") 
 checkAuthors=("${(@u)checkAuthors}") 
done
echo ${#checkAuthors[@]}
#echo ${checkAuthors[@]}

for a in ${checkAuthors[@]}; do
    a=$(echo "$a" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    if [[ ! " ${authorList[*]} " =~ " ${a} " ]]; then
        echo "Adding $a"
        echo $a","$a",," >> scripts/author_list.csv
        echo "---" > "wikipathways.github.io/_authors/$a.md"
        echo "username: $a" >> "wikipathways.github.io/_authors/$a.md"
        echo "realname: $a" >> "wikipathways.github.io/_authors/$a.md"
        echo "website: " >> "wikipathways.github.io/_authors/$a.md"
        echo "affiliation: " >> "wikipathways.github.io/_authors/$a.md"
        echo "bio: " >> "wikipathways.github.io/_authors/$a.md"
        echo "github: " >> "wikipathways.github.io/_authors/$a.md"
        echo "orcid: " >> "wikipathways.github.io/_authors/$a.md"
        echo "linkedin: " >> "wikipathways.github.io/_authors/$a.md"
        echo "googlescholar: " >> "wikipathways.github.io/_authors/$a.md"
        echo "wikidata: " >> "wikipathways.github.io/_authors/$a.md"
        echo "twitter: " >> "wikipathways.github.io/_authors/$a.md"
        echo "mastodon-url: " >> "wikipathways.github.io/_authors/$a.md"
        echo "meta:" >> "wikipathways.github.io/_authors/$a.md"
        echo "instagram:" >> "wikipathways.github.io/_authors/$a.md"
        echo "---" >> "wikipathways.github.io/_authors/$a.md"
    fi
done

##############################
echo "3. ACTION: metadata"

#NOTE: requires Java 11 to be accessible localy

# download all species and metabolite derby database files into top level dir

# cache dependencies
if [ ! -e ./meta-data-action-1.1.1-jar-with-dependencies.jar ]; then
    wget -O meta-data-action-1.1.1-jar-with-dependencies.jar https://github.com/wikipathways/meta-data-action/releases/download/1.1.1/meta-data-action-1.1.1-jar-with-dependencies.jar
    chmod 777 meta-data-action-1.1.1-jar-with-dependencies.jar
fi

for f in ${changed_gpmls[@]}; do
    scripts/meta-data-action/configGenerator.sh $f
    org="$(sed -n '/<Pathway /s/.*Organism=\(.*\)[^\n]*/\1/p' $f | tr -d '"' | tr -d '>' | tr -d '\r')"
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    echo "generating info and datanode files for $wpid ($f)"
    cat gdb.config
    # NOTE: Adapt date arg for macOS (-u) or linux (--utc)
    java -jar meta-data-action-1.1.1-jar-with-dependencies.jar local pathways/"$wpid"/"$wpid".gpml $(date -u +%F) gdb.config "$org" || echo "$wpid FAILED"
done

##############################
echo "3B. TODO-ACTION: meta-data cleanup"

for f in ${changed_gpmls[@]}; do

    # INFO.JSON
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    thisInfo="pathways/$wpid/$wpid-info.json"

    #FOR BULK ACTION ONLY: hack to set last edited to previous info (if available)    
    prevInfo="../wikipathways-database/pathways/$wpid/$wpid-info.json"
    if [ -f $prevInfo ]; then
        prevLastEd="$(sed -n '/\"last-edited\": .*/p' $prevInfo)"
        sed -i '' 's/.*\"last-edited\"\: .*/'"$prevLastEd"'/' "$thisInfo"
    fi

    #BUG FIX: fix authors due to meta-data-action bug
    gpmlAuthors="$(sed -n '/<Pathway /s/.*Author=\"\[\(.*\)\]\".*/\1/p' $f)"
    newAuthors=(`echo $gpmlAuthors | sed 's/\&amp\;amp\;/and/;s/^/\"authors\"\: \[\"/;s/, /\",\"/g;s/$/\"\],/'`)
    sed -i '' 's/\"authors\"\: \[\],/'"$newAuthors"'/' "$thisInfo"

done


##############################
echo "4. ACTION: pubmed"
# NOTE: Requires Node.js v12.x, npm, @citation-js/core
#npm install
#npm install @citation-js/core
node scripts/generate-references/index.js

##############################
echo "5. ACTION: frontmatter"
# NOTE: requires Python 3.x
pip install python-frontmatter

for f in ${changed_gpmls[@]}; do
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    echo "generating frontmatter file for $wpid"
    json_info_f=./pathways/"$wpid"/"$wpid"-info.json
    if [ -e "$json_info_f" ]; then
        python scripts/create_pathway_frontmatter.py "$json_info_f"
    else
        echo "info file missing for $wpid" >2
    fi
done

##############################
echo "6. ACTION: homologyConversion"
# NOTE: requires Java 8 
if [ ! -e ./Hs_Derby_Ensembl_108.bridge ]; then
    wget -O Hs_Derby_Ensembl_108.bridge "https://zenodo.org/record/7781913/files/Hs_Derby_Ensembl_108.bridge?download=1"
fi

for f in ${changed_gpmls[@]}; do
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    echo "perfoming homology conversion for $wpid ($f)"
    java -jar HomologyMapperAuto-WithDependencies.jar scripts/homology-converter/properties/autorun.properties $wpid
done

echo "TODO: Manually copy scripts/homology-converter/outputs folder content to wikipathways-homology repo for commit/push"

##############################
echo "7. ACTION: json-svg"
# NOTE: Requires Node.js v12.x, npm, convert-svg-to-png, and xlmstarlet
#npm install
#npm install --save convert-svg-to-png
#sudo apt-get install -y xmlstarlet
#brew install xmlstarlet

AS_PATH="wikipathways-assets"
mkdir $AS_PATH
for f in ${changed_gpmls[@]}; do
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    echo "generating JSON and SVG files for $wpid"
    mkdir -p "$AS_PATH"/pathways/"$wpid"
            
    for old_f in "$AS_PATH"/pathways/"$wpid"/"$wpid".{json,svg}; do 
        if [ -e "$old_f" ]; then
            rm "$old_f"
        fi
    done
    
    cd scripts/generate-svgs
    ./gpmlconverter --id "$wpid" -i ../../pathways/"$wpid"/"$wpid".gpml -o ../../$AS_PATH/pathways/"$wpid"/"$wpid".svg
    cd ../../

    # delete intermediate JSON files
    rm $AS_PATH/pathways/"$wpid"/"$wpid".json.b4bridgedb.json || true
    rm $AS_PATH/pathways/"$wpid"/"$wpid".b4wd.json || true
    rm $AS_PATH/pathways/"$wpid"/"$wpid".b4hgnc.json || true
            
    # mv thumbnail png
    mv $AS_PATH/pathways/"$wpid"/"$wpid"-thumb.png pathways/"$wpid"/
    # pretty print the JSON
    for json_f in $AS_PATH/pathways/"$wpid"/"$wpid".json; do
        mv "$json_f" "$json_f".tmp.json 
        jq -S . "$json_f".tmp.json >"$json_f"
        rm "$json_f".tmp.json
    done
done

echo "TODO: Manually copy wikipathways-assets folder content to wikipathways-assets repo for commit/push"


##############################
echo "8. ACTION: sync-site-repo-added-modified"
mkdir -p "wikipathways.github.io/assets/img"
mkdir -p "wikipathways.github.io/_pathways"
mkdir -p "wikipathways.github.io/_data"
for f in ${changed_gpmls[@]}; do
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    cp pathways/"$wpid"/"$wpid".md wikipathways.github.io/_pathways/
    cp pathways/"$wpid"/"$wpid"-bibliography.tsv wikipathways.github.io/_data/
    cp pathways/"$wpid"/"$wpid"-datanodes.tsv wikipathways.github.io/_data/
    mkdir -p wikipathways.github.io/assets/img/"$wpid"
    cp pathways/"$wpid"/"$wpid"-thumb.png wikipathways.github.io/assets/img/"$wpid"/
done

echo "TODO: Manually copy wikipathways.github.io folder content to wikipathways.github.io repo for commit/push"

#####################
echo "DONE"
