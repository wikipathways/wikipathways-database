# Welcome to the WikiPathways Database
This repository is the primary database for pathway content for the WikiPathways project, including the source for content at www.wikipathways.org.

## General Usage
Users may be directed here by edit links on the website (e.g., pencil icons). Changes made to the files here will be reflected on the website after a few minutes.

Technically, edits made using the pathway editor, PathVisio, also update the files here. However, most users do not need to worry about this.

If you want to make edits to a pathway at WikiPathways, DO NOT create pull requests directly for this repo. Instead, use the PathVisio tool with the WikiPathways plugin to edit existing pathways and contribute new pathways.

## Development
Please use caution when commit directly to this repository. Various GitHub Action are triggered by new commits. Please review the workflows in the `.github/workflows` directory and ask other developers on Slack if uncertain before making changes.

### Update Protocol
The GitHub actions specifiy versions for various tools and resources. Developers are responsible for keeping these up-to-date. GitHub Actions will report pending deprecations on each run. Please take note of these and update the version numbers accordingly. These might include:
 * Node.js
 * Ubuntu _(consider using ubuntu-latest)_
 * Syntax for things like environment variables and secrets

 Marketplace actions also need to be updated. These might include:
 * actions/checkout
 * actions/setup-java
 * actions/setup-node
 * actions/setup-python
 * actions/cache
 * r-lib/actions/setup-r

 Finally, our own tools and resources will require updates. These might include:
 * meta-data-action jar
 * SyncAction jar
 * Caches of bridgedb files
