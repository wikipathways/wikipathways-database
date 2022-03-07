
# Annotations
There are folders per annotation source (e.g., pw = Pathway Ontology). Within each folder is a .csv table used to lookup identifiers to retrieve labels, urls and other useful information. This information is used to complete the `annotations` section of pathway .md files.

## Annotation Types
This is a list of the "official" names of the annotations used throughout the code for consistency and automated parsing:

1. Pathway Ontology
2. Disease
3. Cell Type

These type names are used in the pathway .md files.

If you add a new annotation source or change any of the above, then you are responsible for updating *all* the places these standardized type names have been previously used.

## How to Use Files
The first two columns are essentially all you need:

1. **Class ID**: A URL for linkouts, but also includes the identifier in an easy-to-parse form, e.g., `http://purl.obolibrary.org/obo/PW_0000003`. Use this column to match identifiers from .gpml (or .info) files.
2. **Preferred Label**: The human-readable label. Use this column to provide labels in the pathway .md files.


## How to Update Files
Run the following commands:

```
#Pathway Ontology
wget -O PW.csv.gz 'https://data.bioontology.org/ontologies/PW/download?apikey=8b5b7825-538d-40e0-9e9e-5ab9274a9aeb&download_format=csv'
gunzip PW.csv.gz

#Disease
wget -O DOID.csv.gz 'https://data.bioontology.org/ontologies/DOID/download?apikey=8b5b7825-538d-40e0-9e9e-5ab9274a9aeb&download_format=csv'
gunzip DOID.csv.gz

#Cell Type
wget -O CL.csv.gz 'https://data.bioontology.org/ontologies/CL/download?apikey=8b5b7825-538d-40e0-9e9e-5ab9274a9aeb&download_format=csv'
gunzip CL.csv.gz

# TODO: Make a GitHub action do this quarterly
```




