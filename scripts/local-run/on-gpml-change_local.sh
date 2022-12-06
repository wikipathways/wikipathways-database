#!/bin/zsh

# This script reproduces the on-gpml-change GH Action as a script 
# to be run locally.

###################################
echo "1. Define list of GPML files"

# 1A. Either as a local folder containing GPML files
changed_dir="pathways_changed" #set to "" to use 1B instead

# 1B. Or as a list of WPIDs referencing GPMLs in existing pathway subfolders
changed_wpids=() #WPIDs or use keyword "ALL"

# Identify file paths to changed GPMLs; creating them if necessary.
changed_gpmls=()
if [ ! -z "$changed_dir" ]; then
    for i in "$changed_dir"/*.gpml; do
        this_wpid="$(basename -s .gpml $i)"
        this_dir="pathways/$this_wpid"
        if [ ! -d "$this_dir" ]; then
            mkdir -p pathways/"$this_wpid"
        fi
        new_path=$this_dir"/"$this_wpid".gpml"
        cp $i $new_path
        echo $new_path
        changed_gpmls+="$new_path"
    done
else
    if [ -z "$changed_wpids" ]; then
        echo "Set either changed_dir or changed_wpids."
        echo "EXITING"
        exit 1;
    elif [ "${changed_wpids[@]}"=="ALL" ]; then
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
        if [ -f $i ]; then
            echo "$i"
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
echo "2. ACTION: wpid-list"

cd pathways
cat /dev/null > ../wpid_list.txt
for d in ./*; do
    [[ -d "$d" ]] && echo "${d##./}" >> ../wpid_list.txt; 
done
cd ../

##############################
echo "3. ACTION: metadata"

#NOTE: requires Java 11 to be accessible localy

# cache dependencies
if [ ! -e ./meta-data-action-1.0.3-jar-with-dependencies.jar ]; then
    wget -O meta-data-action-1.0.3-jar-with-dependencies.jar https://github.com/hbasaric/meta-data-action/releases/download/v1.0.0/meta-data-action-1.0.3-jar-with-dependencies.jar
fi

# configGenerator
for f in ${changed_gpmls[@]}; do
    scripts/meta-data-action/configGenerator.sh $f
done

# installDependencies, a.k.a. BridgeDb files; each only has to be downloaded once 
for f in ${changed_gpmls[@]}; do
    org="$(sed -n '/<Pathway /s/.*Organism=\(.*\)[^\n]*/\1/p' $f | tr -d '"' | tr -d '>' | tr -d '\r'| tr -d ' ')"
    scripts/meta-data-action/installDependencies.sh $org
done

# generate info and datanodes files (NOTE: Adapted date for macOS (-u instead of --utc))
for f in ${changed_gpmls[@]}; do
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    org="$(sed -n '/<Pathway /s/.*Organism=\(.*\)[^\n]*/\1/p' $f | tr -d '"' | tr -d '>' | tr -d '\r')"
    echo "generating info and datanode files for $wpid ($f)"
    chmod 777 meta-data-action-1.0.3-jar-with-dependencies.jar
    cat gdb.config
    ##TODO: make independent of GPMLs in github repo
    java -jar meta-data-action-1.0.3-jar-with-dependencies.jar wikipathways/wikipathways-database pathways/"$wpid"/"$wpid".gpml $(date -u +%F) gdb.config "$org"
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
    old_info_f=./pathways/"$wpid"/"$wpid".info
    if [ -e "$json_info_f" ]; then
        python scripts/create_pathway_frontmatter.py "$json_info_f"
    elif [ -e "$old_info_f" ]; then
        python scripts/create_pathway_frontmatter.py "$old_info_f"
    else
        echo "info file missing for $wpid" >2
    fi
done

##############################
echo "6. ACTION: homologyConversion"
# NOTE: requires Java 8 
if [ ! -e ./Hs_Derby_Ensembl_105.bridge ]; then
    wget -O Hs_Derby_Ensembl_105.bridge "https://zenodo.org/record/6502115/files/Hs_Derby_Ensembl_105.bridge?download=1"
                                        
fi

for f in ${changed_gpmls[@]}; do
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    echo "perfoming homology conversion for $wpid ($f)"
    java -jar HomologyMapperAuto-WithDependencies.jar scripts/homology-converter/properties/autorun.properties $wpid
done

HM_PATH="wikipathways-homology"
mkdir $HM_PATH
for f in ${changed_gpmls[@]}; do
    wpid="$(basename ""$f"" | sed 's/.gpml//')"
    echo "copying gpml files for $wpid for all species"
            
    for value in Bt Cf Dr Qc Gg Mm Pt Rn Ss; do
        mkdir -p "$HM_PATH"/pathways/$value/"$wpid"
        for old_f in "$HM_PATH"/pathways/$value/"$wpid"/"$wpid"_"$value".gpml; do 
            echo "for $old_f in $HM_PATH/pathways/$value/"$wpid"/"$wpid"_"$value".gpml"
            if [ -e "$old_f" ]; then
                rm "$old_f"
                echo "rm $old_f"
            fi
        done
        if [-e scripts/homology-converter/outputs/$value/"$wpid"/"$wpid"_"$value".gpml]; then
            cp scripts/homology-converter/outputs/$value/"$wpid"/"$wpid"_"$value".gpml $HM_PATH/pathways/$value/"$wpid"/"$wpid"_"$value".gpml
        fi
    done  
done

echo "TODO: Manually copy wikipathways-homology folder content to wikipathways-homology repo for commit/push"

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
mkdir "wikipathways.github.io"
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