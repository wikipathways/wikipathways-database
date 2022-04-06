import csv
from datetime import date
import frontmatter
from frontmatter.default_handlers import YAMLHandler
from io import BytesIO
from pathlib import Path
import sys


repo_dir = Path('./')
communities_p = repo_dir.joinpath('communities/')

communities_by_wpid = dict()

for p in communities_p.glob('**/*.txt'):
    community = p.stem
    with p.open() as f:
        for wpid in f.read().splitlines():
            if not wpid in communities_by_wpid:
                communities_by_wpid[wpid] = set()

            communities_by_wpid[wpid].add(community)

for wpid, communities in communities_by_wpid.items():
    frontmatter_p = repo_dir.joinpath('pathways/' + wpid + '/' + wpid + '.md')
    
    if not frontmatter_p.exists():
        print(f"{frontmatter_p} does not exist, but {wpid} is in communities directory")
        continue

    post = frontmatter.load(str(frontmatter_p), handler=YAMLHandler())
    post['communities'] = list(communities)

    with frontmatter_p.open('wb') as f:
        frontmatter.dump(post, f)
