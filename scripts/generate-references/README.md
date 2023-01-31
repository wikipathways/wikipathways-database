# Generate references

Script to generate formatted references for identifiers extracted from pathways.

## Usage

The script runs on TSV files in `pathways/*/*-refs.tsv` and expects there to be
two columns, the first the identifier and the second the database. It outputs
the formatted references in TSV files in `pathways/*/*-bibliography.tsv`, with
three columns. The first two columns are the same as the input, and the third
contains the formatted reference. The reference is enclosed in double quotes and
any literal double quotes are escaped (i.e. `"` → `""`).

## Adding databases

The `DATABASE_TYPE_MAP` contains mappings of values of the `Database` column in
the input, to [Citation.js](https://citation.js.org/) types. Not all values in
the `Database` are included, as the value `DOI` can be mapped to multiple types
(URL, short URL, DOI only), as can the value `ISBN` (ISBN-10, ISBN-13), and these
can be recognized automatically anyway.

| Database | Citation.js type |
|----------|------------------|
| `Pubmed` | `@pubmed/id`     |
| `DOI`    | `@doi/id`, `@doi/api`, `@doi/short-url` |
| `ISBN`   | `@isbn/isbn-10`, `@isbn/isbn-13` |

The `DATABASE_LINKS` defines which links to append to each reference. Each entry
in the object should be an array, where each element is a pair of values:

  1. The text to display
  2. A monadic function that takes the identifier of the reference, and returns
     an url

## Maintenance

Update dependencies:

    npm update

Major (breaking) updates:

    npm install <DEPENDENCY>@latest

## License

See the [`LICENSE`](./LICENSE) file.
