import frontmatter
from frontmatter.default_handlers import YAMLHandler
from pathlib import Path
import glob

repo_dir = Path('./')

c = repo_dir.joinpath('downstream/citedin_lookup.yml')
citedin = frontmatter.load(str(c), handler=YAMLHandler())

wpids = list(citedin.keys()) #keys from citedin
wpids.remove('last_run')

temp_path = r'pathways/{wpid}/{wpid}.md'
var_path = lambda wpid: temp_path.format(wpid=wpid)

for wpid in wpids:
    print(wpid)
    p = repo_dir.joinpath(var_path(wpid))
    if p.is_file():
        post = frontmatter.load(str(p), handler=YAMLHandler())
        
        old_citedin = post.get('citedin', str())
        new_citedin = citedin.get(wpid, str())
        
        if new_citedin:
            print(f"updating {wpid} citedin from {old_citedin} to {new_citedin}")
            post['citedin'] = new_citedin
            with Path(p).open('wb') as f:
                frontmatter.dump(post, f)
    else:
        print(f'The file {p} does not exist, possibly deleted')
