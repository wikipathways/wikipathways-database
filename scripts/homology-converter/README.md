# homologyConverterActions

This repository is a prototype to test using GitHub Actions to trigger the automated homology conversion script to run when a .gpml file is changed.

When a new pathway is added  to the /pathways folder, or an existing pathway is modified, the on_gpml_change.yml file triggers a workflow run.

The workflow run installs the necessary dependency; Hs_Derby_Ensembl_105.bridge from https://bridgedb.github.io/data/gene_database/ using a wget statement.

The line java -jar HomologyMapperAuto-WithDependencies.jar properties/autorun.properties $wpid runs the automated Local Homology Converter (https://github.com/hbasaric/homology.mapper.automated/). The converted pathway will only be committed if the conversion rate is greater than 80%.

Two arguments are provided to the java application; the autorun.properties file which specifies run configurations, as well as the WP ids for the pathways that were changed or added to the /pathways folder. The WP ids are determined by the yml script, in the "Get changed files" step.

All required inputs are contained within this repository (in the /genes and /homology folders).
