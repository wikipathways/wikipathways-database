These "lookup" files track references to WikiPathways content at various source downstream of their creation and curation.

## NDEx
The NDEx database hosts CX versions of WikiPathways content for ready visualization and analysis in Cytoscape and cytoscape.js.  

The script to update the latest mappings between WikiPathways and NDEx is [here](../scripts/ndex_lookup.R).

## Cited In
There are many references to WikiPathways content (e.g., WP554) in the literature, even if wikipathways is not cited. We automatically capture these with a script that searches for the co-occurence of a WPID and "WikiPathways". The `citedin_lookup.yml` list can also be manually updated to include any citations (PubMed ID, PMCID, DOI or URL) as `link` elements, along with `title` elements that are displayed as tooltips.  If one archives a particular version of a pathway (e.g., as PDF or image via Zenodo), then that can be captured as `archived` elements as part of the same list item.

The script to update the latest references to WikiPathways in the literature runs weekly and can be found [here](../scripts/citedin_lookup.R).
