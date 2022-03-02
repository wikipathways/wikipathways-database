import csv
from datetime import date
import frontmatter
from frontmatter.default_handlers import YAMLHandler
from io import BytesIO
from pathlib import Path
import sys


communities_fp = Path('./wikipathways-database/communities/')

communities_by_wpid = dict()

for f in communities_fp.glob('**/*.txt'):
    community = f.stem
    for wpid in f.readlines():
        if not wpid in communities_by_wpid:
            communities_by_wpid[wpid] = set()

        communities_by_wpid[wpid].add(community)


for wpid, communities in communities_by_wpid:
    frontmatter_f = './wikipathways-database/pathways/' + wpid + '/' + wpid + '.md'

    post = frontmatter.load(frontmatter_f, handler=YAMLHandler())
    post['communities'] = list(communities)

    print(wp)
    print(communities)

    with open(frontmatter_f, 'wb') as f:
        frontmatter.dump(post, f)
