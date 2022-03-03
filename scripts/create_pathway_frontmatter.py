import csv
from datetime import date
import frontmatter
from frontmatter.default_handlers import YAMLHandler
from io import BytesIO
import json
from pathlib import Path
import sys


annotations_types = {
    'PW': 'Pathway Ontology',
    'CL': 'Cell Type Ontology',
    'DOID': 'Disease Ontology',
}

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

post = frontmatter.loads('---\n---')

with open(info_f) as f:
    for line in f:
        if not line.strip():
            continue
        elif line.strip()[-1] == ':':
            key = line.strip()[:-2]
            if key in ['description']:
                post[key] = ''

            continue

        key, value = line.strip().split(': ', 1)

        if key == 'authors':
            post[key] = [v.strip() for v in value[1:-1].split(',')]
        elif key == 'ontology-ids':
            # annotations:
            #   - value: angiotensin signaling pathway
            #     type: Pathway Ontology
            annotations = []
            for ontology_id in value.split(','):
                datasource, id_number = ontology_id.strip().split(':', 1)
                annotation = dict()
                annotation['type'] = annotations_types[datasource]
                with open('./wikipathways-database/annotations/' + datasource + '.csv') as f:
                    reader = csv.DictReader(f, quoting=csv.QUOTE_NONE)
                    for l in reader:
                        if l['Class ID'] == 'http://purl.obolibrary.org/obo/' + datasource + '_' + id_number:
                            annotation['value'] = l['Preferred Label']
                            annotations.append(annotation)
                            break
            post['annotations'] = annotations
        elif key == 'last-edited':
            # 20210601215335 -> datetime.date(2021, 6, 1)
            post[key] = date(int(value[0:4]), int(value[4:6]), int(value[6:8]))
        elif key == 'organisms':
            post[key] = [value]
        else:
            post[key] = value

if not 'title' in post:
    post['title'] = ''
if not 'description' in post:
    post['description'] = ''

datanode_labels = set()
with open('./wikipathways-database/pathways/' + wpid + '/' + wpid + '-datanodes.tsv') as f:
    reader = csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
    for line in reader:
        datanode_labels.add(line['Label'])

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
    #'/instance/' + wpid + '_r' + post['revision'],
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
