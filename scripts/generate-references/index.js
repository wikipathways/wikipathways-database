const path = require('path')
const { promises: fs, existsSync } = require('fs')
const { Cite } = require('@citation-js/core')
require('@citation-js/plugin-pubmed')
require('@citation-js/plugin-csl')

function readCsv (file, cache) {
    const lines = file.match(/("([^"]|"")*"|[^\n"]+)+/g)
    for (const line of lines.slice(1)) {
        if (!line.length) continue
        const [id, database, ...reference] = line.split('\t')
        cache.set(`${database}:${id}`, reference.join('\t'))
    }

    return cache
}

function escapeCsvValue (value) {
    value = value == null ? '' : value.toString()
    if (/["\t]/.test(value)) {
        return `"${value.replace(/"/g, '""')}"`
    } else {
        return value
    }
}

const DATABASE_TYPE_MAP = {
    'Pubmed': '@pubmed/id'
}

const DATABASE_LINKS = {
    'Pubmed': [
        ['PubMed', id => `http://www.ncbi.nlm.nih.gov/pubmed/${id}`],
        ['Europe PMC', id => `https://europepmc.org/abstract/MED/${id}`],
        ['Scholia', id => `https://scholia.toolforge.org/pubmed/${id}`]
    ]
}

function formatLink (text, url) {
    return `<a href="${url}" target="_blank" class="external" rel="nofollow">${text}</a>`
}

async function format (id, database) {
    const forceType = DATABASE_TYPE_MAP[database]
    const append = DATABASE_LINKS[database]
        .map(([text, url]) => ' ' + formatLink(text, url(id)))
        .join('')

    return Cite.async(id, { forceType })
        .then(cite => cite.format('bibliography', { template: 'vancouver', append }))
        .then(ref => ref.trim().replace(/^1.\s+/, ''))
}

const PROJECT_DIR = path.join(__dirname, '..', '..')
const PATHWAY_DIR = path.join(PROJECT_DIR, 'pathways')

function getReferencesFile (pathway) {
    return path.join(PATHWAY_DIR, pathway, `${pathway}-bibliography.tsv`)
}

function sortIdentifier (a, b) {
    // If not same database, sort by database
    if (a[1] !== b[1]) {
        return a[1] > b[1] ? 1 : -1
    }

    return a[0].localeCompare(b[0], undefined, { numeric: true })
}

async function main () {
    const cache = new Map()
    const pathways = await fs.readdir(PATHWAY_DIR)

    const existingFiles = await Promise.all(
        pathways
            .map(pathway => getReferencesFile(pathway))
            .filter(file => existsSync(file))
            .map(file => fs.readFile(file, 'utf8'))
    )
    existingFiles.forEach(file => readCsv(file, cache))

    for (const pathway of pathways) {
        console.log('Processing pathway:', pathway)

        const refsFile = path.join(PATHWAY_DIR, pathway, `${pathway}-refs.tsv`)

        if (!existsSync(refsFile)) {
            console.log(`  no ${pathway}-refs.tsv file, skipping`)
            continue
        }

        const file = await fs.readFile(refsFile, 'utf8')
        const table = []

        for (const row of file.trim().split('\n').slice(1)) {
            const [id, database] = row.split('\t').map(value => value.trim())
            if (!id.length) {
                console.log('  skipping empty row')
                continue
            }

            const cacheKey = `${database}:${id}`
            if (cache.has(cacheKey)) {
                console.log(`  ${cacheKey}: using cache`)
            } else {
                console.log(`  ${cacheKey}: generating reference`)
                try {
                    cache.set(cacheKey, escapeCsvValue(await format(id, database)))
                } catch (e) {
                    console.log('    Error:', e.message)
                    continue
                }
            }
            table.push([id, database, cache.get(cacheKey)])
        }

        table.sort(sortIdentifier)
        table.unshift(['ID', 'Database', 'Citation'])

        await fs.writeFile(
            getReferencesFile(pathway),
            table.map(row => row.join('\t')).join('\n') + '\n'
        )
    }
}

main().catch(console.error)
