import csv
import frontmatter
from frontmatter.default_handlers import YAMLHandler
from pathlib import Path
import glob

repo_dir = Path('./')

ndex_by_wpid = {}

with open(repo_dir.joinpath('downstream/ndex_lookup.csv')) as f:
    reader = csv.DictReader(f)
    for row in reader:
        ndex_by_wpid[row['wpid']] = row['ndexid']

wpids = set()
for p in repo_dir.joinpath('pathways/').glob('WP*/WP*.md'):
    wpid = Path(p).stem
    wpids.add(wpid)
    print(wpid)

    post = frontmatter.load(str(p), handler=YAMLHandler())
    
    old_ndex = post.get('ndex', str())
    print(old_ndex)
    new_ndex = ndex_by_wpid.get(wpid)
    
    if new_ndex:
        print(f"updating {wpid} ndex from {old_ndex} to {new_ndex}")
        post['ndex'] = new_ndex
        with Path(p).open('wb') as f:
            frontmatter.dump(post, f)      

# wpids specified in ndex_lookup.csv without corresponding wpids in ./pathways
non_existent_wpids = set(ndex_by_wpid.keys()) - wpids
if non_existent_wpids:
    print(f"wpids in ndex_lookup.csv but not in ./pathways: {non_existent_wpids}")