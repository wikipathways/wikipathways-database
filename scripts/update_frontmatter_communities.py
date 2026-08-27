import csv
from datetime import date
import frontmatter
from frontmatter.default_handlers import YAMLHandler
from io import BytesIO
from pathlib import Path
import sys


repo_dir = Path('./')

communities_by_wpid = dict()

for p in sorted(repo_dir.joinpath('communities/').glob('**/*.txt')):
    community = p.stem
    with p.open() as f:
        for wpid in f.read().splitlines():
            if not wpid in communities_by_wpid:
                communities_by_wpid[wpid] = list()

            communities_by_wpid[wpid].append(community)

wpids = set()
for p in repo_dir.joinpath('pathways/').glob('WP*/WP*.md'):
    wpid = p.stem
    wpids.add(wpid)

    post = frontmatter.load(str(p), handler=YAMLHandler())
    
    old_communities = post.get('communities', list())
    new_communities = communities_by_wpid.get(wpid, list())
    
    if old_communities != new_communities:
        print(f"updating {wpid} communities from {old_communities} to {new_communities}")
        post['communities'] = new_communities
        # dumps() returns str on every python-frontmatter release; dump() to a
        # file handle does not -- older versions encode and need 'wb', newer
        # ones write str and need 'w', so either mode alone breaks on the other.
        # Opening the file is also what truncates it, so the mismatch does not
        # just fail, it empties the .md before raising.
        p.write_text(frontmatter.dumps(post), encoding='utf-8')

# wpids specified in ./communities without corresponding wpids in ./pathways
non_existent_wpids = set(communities_by_wpid.keys()) - wpids
if non_existent_wpids:
    print(f"wpids in ./communities but not in ./pathways: {non_existent_wpids}")
