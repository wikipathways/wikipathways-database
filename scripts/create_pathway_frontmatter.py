import csv
from datetime import date
import frontmatter
from frontmatter.default_handlers import YAMLHandler
from io import BytesIO
from pathlib import Path
import sys


info_f = sys.argv[1]
if not info_f:
    raise Exception('No info_f provided')

info_fp = Path(info_f)
wpid = info_fp.stem


frontmatter_fp = Path('./wikipathways-database/pathways/' + wpid + '/' + wpid + '.md')
frontmatter_f = str(frontmatter_fp)
if frontmatter_fp.exists():
    post = frontmatter.load(frontmatter_f, handler=YAMLHandler())
else:
    # TODO: is there a better way to create an empty post object?
    post = frontmatter.loads('---\n---')

with open(info_f) as f:
    for line in f:
        key, value = line.strip().split(': ', 1)

        if key == 'authors':
            value = [v.strip() for v in value.split('|')]
        elif key == 'ontology-ids':
            # TODO: we don't want the IDs; instead we want this:
            # annotations:
            #   - value: angiotensin signaling pathway
            #     type: Pathway Ontology
            value = [v.strip() for v in value.split(',')]
        elif key == 'last-edited':
            # 20210601215335 -> datetime.date(2021, 6, 1)
            value = date(int(value[0:4]), int(value[4:6]), int(value[6:8]))
            # 20210601215335 -> 2021-06-01 -> datetime.date(2021, 6, 1)
            #value = date.fromisoformat('-'.join([value[0:4], value[4:6], value[6:8]]))
        elif key == 'organisms':
            value = [value]

        post[key] = value

datanode_labels = set()
with open('./wikipathways-database/pathways/' + wpid + '/' + wpid + '-datanodes.tsv') as f:
    reader = csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
    for line in reader:
        datanode_labels.add(line['Label'])

# TODO: Tina will add this.
#post['github-authors'] = []

post['redirect_from'] = [
    '/index.php/Pathway:' + wpid,
    '/instance/' + wpid,
    '/instance/' + wpid + '_r' + post['revision'],
]

post['seo'] = 'CreativeWork'

post['schema-jsonld'] = [{
    '@context': 'https://schema.org/',
    '@id': 'https://wikipathways.github.io/pathways/' + wpid + '.html',
    '@type': 'Dataset',
    'name': post['title'],
    'description': post['description'],
    'license': 'CC0',
    'creator': {'@type': 'Organization', 'name': 'WikiPathways'},
    'keywords': list(datanode_labels),
}]

with open(frontmatter_f, 'wb') as f:
    frontmatter.dump(post, f)
