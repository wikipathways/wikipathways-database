import csv
from datetime import date
import frontmatter
from io import BytesIO
import sys


# TODO: should we do the mappings here or in the .info file?
info_to_frontmatter = {
    'ID': 'wpid',
    'Species': 'organisms',
    'Date': 'last-edited',
}

info_fp = sys.argv[1]
if not info_fp:
    raise Exception('No info_fp provided')
# TODO: detect the file that changed; don't hardcode this.
#info_fp = './wikipathways-database/pathways/WP5/WP5.info'

# TODO: is there a better way to create an empty post object?
post = frontmatter.loads('---\n---')
with open(info_fp) as f:
    for line in f:
        key, value = line.strip().split(': ', 1)
        if key in info_to_frontmatter:
            key = info_to_frontmatter[key]
        else:
            key = key.lower()

        if key == 'authors':
            value = [v.strip() for v in value.split('|')]
        elif key == 'ontology tags':
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
with open('./wikipathways-database/pathways/WP554/WP554-datanodes.tsv') as f:
    reader = csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
    for line in reader:
        datanode_labels.add(line['Label'])

# TODO: fill in the following
if not post['title']:
    post['title'] = ''
post['communities'] = []
post['github-authors'] = []

post['redirect_from'] = [
    '/index.php/Pathway:' + post['wpid'],
    '/instance/' + post['wpid'],
    '/instance/' + post['wpid'] + '_r' + post['revision'],
]

post['seo'] = 'CreativeWork'

post['schema-jsonld'] = [{
    '@context': 'https://schema.org/',
    '@id': 'https://wikipathways.github.io/pathways/' + post['wpid'] + '.html',
    '@type': 'Dataset',
    'name': post['title'],
    'description': post['description'],
    'license': 'CC0',
    'creator': {'@type': 'Organization', 'name': 'WikiPathways'},
    'keywords': list(datanode_labels),
}]

with open('./wikipathways-database/pathways/' + post['wpid'] + '/' + post['wpid'] + '.md', 'wb') as f:
    frontmatter.dump(post, f)
