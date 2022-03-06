import csv
from datetime import date
import frontmatter
from frontmatter.default_handlers import YAMLHandler
from io import BytesIO
import json
from pathlib import Path
import re
import sys


ANNOTION_TYPE_BY_NAMESPACE = {
        'PW': 'Pathway Ontology',
        'CL': 'Cell Type Ontology',
        'DOID': 'Disease Ontology',
        }

PARENT_ANNOTATION_IRIS_BY_DATASOURCE = {
        'PW': set([
            'http://purl.obolibrary.org/obo/PW_0000002',
            'http://purl.obolibrary.org/obo/PW_0000003',
            'http://purl.obolibrary.org/obo/PW_0000004',
            'http://purl.obolibrary.org/obo/PW_0000013',
            'http://purl.obolibrary.org/obo/PW_0000754'
            ]),
        'DOID': set([
            'http://purl.obolibrary.org/obo/DOID_0014667',
            'http://purl.obolibrary.org/obo/DOID_0050117',
            'http://purl.obolibrary.org/obo/DOID_14566',
            'http://purl.obolibrary.org/obo/DOID_150',
            'http://purl.obolibrary.org/obo/DOID_630'
            ]),
        'CL': set([
            'http://purl.obolibrary.org/obo/CL_0000003',
            'http://purl.obolibrary.org/obo/CL_0000034',
            'http://purl.obolibrary.org/obo/CL_0000064',
            'http://purl.obolibrary.org/obo/CL_0000255',
            'http://purl.obolibrary.org/obo/CL_0000445',
            'http://purl.obolibrary.org/obo/CL_0000520',
            'http://purl.obolibrary.org/obo/CL_0000548',
            'http://purl.obolibrary.org/obo/CL_0000627',
            'http://purl.obolibrary.org/obo/CL_0007001'
            ])
        }

SUPPORTED_DATASOURCES = set([
    'PW',
    'DOID',
    'CL',
    ])

DATASOURCE_RE = re.compile(r'http://purl.obolibrary.org/obo/([A-Z]+)_\d+')


def get_datasource(iri):
    m = DATASOURCE_RE.fullmatch(iri)
    if m:
        return m.group(1)

def get_annotation_details(iri):
    datasource = get_datasource(iri)
    with open('./annotations/' + datasource + '.csv') as f:
        reader = csv.DictReader(f)
        for l in reader:
            if l['Class ID'] == iri:
                return l

def parse_parent_parent_iri(raw_parent_iri):
    parent_iris = []
    for parent_iri in raw_parent_iri.strip().split('|'):
        datasource = get_datasource(parent_iri)
        if datasource in SUPPORTED_DATASOURCES:
            parent_iris.append(parent_iri)
    return parent_iris

# TODO: what's the difference between the key 'Parents' and
# the key 'http://data.bioontology.org/metadata/treeView'?
def get_parent_annotation_preferred_label(parent_iri, child_iri = ''):
    datasource = get_datasource(parent_iri)

    if (not parent_iri) or (parent_iri == child_iri):
        return None

    if parent_iri in PARENT_ANNOTATION_IRIS_BY_DATASOURCE[datasource]:
        annotation_details = get_annotation_details(parent_iri)
        return annotation_details['Preferred Label']

    annotation_details = get_annotation_details(parent_iri)

    for grandparent_iri in parse_parent_parent_iri(annotation_details['Parents']):
        preferred_label = get_parent_annotation_preferred_label(
                grandparent_iri,
                parent_iri)
        if preferred_label:
            return preferred_label 


info_f = sys.argv[1]
if not info_f:
    raise Exception('No info_f provided')

info_fp = Path(info_f)
wpid = info_fp.stem


frontmatter_fp = Path('./pathways/' + wpid + '/' + wpid + '.md')
frontmatter_f = str(frontmatter_fp)
if frontmatter_fp.exists():
    post = frontmatter.load(frontmatter_f, handler=YAMLHandler())
else:
    # TODO: is there a better way to create an empty post object?
    post = frontmatter.loads('---\n---')

with open(info_f) as f:
    # TODO: once Tina update the metadata file to use JSON, we can
    # just use the following line and delete the rest of this block.
    #parsed_metadata = json.load(f)

    parsed_metadata = {}
    for line in f:
        try:
            key, value = line.strip().split(': ', 1)
        except Exception:
            print("create_pathway_frontmatter.py error - Failed to parse .info file line: " + line)
            print(info_fp)
            continue

        if key == 'authors':
            parsed_metadata[key] = [v.strip() for v in value[1:-1].split(',')]
        elif key == 'ontology-ids':
            parsed_metadata['ontology-ids'] = value.split(',')
        elif key == 'organisms':
            parsed_metadata[key] = [value]
        else:
            parsed_metadata[key] = value

for key, value in parsed_metadata.items():
        if key == 'ontology-ids':
            annotations = []
            for ontology_id in value:
                datasource, id_number = ontology_id.strip().split(':', 1)

                annotation = {
                        'id': ontology_id,
                        'type': ANNOTION_TYPE_BY_NAMESPACE[datasource]
                        }

                annotations.append(annotation)

                iri = 'http://purl.obolibrary.org/obo/' + datasource + '_' + id_number
                annotation_details = get_annotation_details(iri)
                if annotation_details:
                    annotation['value'] = annotation_details['Preferred Label']
                    annotation['parent'] = get_parent_annotation_preferred_label(iri)

            post['annotations'] = annotations
        elif key == 'last-edited':
            # 20210601215335 -> datetime.date(2021, 6, 1)
            post[key] = date(int(value[0:4]), int(value[4:6]), int(value[6:8]))
        else:
            post[key] = value

if not 'title' in post:
    post['title'] = ''
if not 'description' in post:
    post['description'] = ''

datanode_labels = set()
with open('./pathways/' + wpid + '/' + wpid + '-datanodes.tsv') as f:
    reader = csv.DictReader(f, delimiter="\t")
    for line in reader:
        datanode_labels.add(line['Label'])

# TODO: Tina will add this.
#post['github-authors'] = []

post['redirect_from'] = [
    '/index.php/Pathway:' + wpid,
    '/instance/' + wpid,
]
if 'revision' in post:
    post['redirect_from'].append(
            '/instance/' + wpid + '_r' + post['revision']
            )

post['seo'] = 'CreativeWork'

post['schema-jsonld'] = [{
    '@context': 'https://schema.org/',
    '@id': 'https://wikipathways.github.io/pathways/' + wpid + '.html',
    '@type': 'Dataset',
    'name': post['title'],
    'description': post['description'],
    'license': 'CC0',
    'creator': {'@type': 'Organization', 'name': 'WikiPathways'},
    'keywords': sorted(datanode_labels),
}]

with open(frontmatter_f, 'wb') as f:
    frontmatter.dump(post, f)
