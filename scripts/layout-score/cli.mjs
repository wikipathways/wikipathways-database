#!/usr/bin/env node
// Layout score of a pathway edit, for the "Automated Testing" table of a pull request.
//
//   node cli.mjs --pr WP534__PR123.gpml [--base pathways/WP534/WP534.gpml]
//                [--json layout-score.json] [--markdown layout-score.md] [--env "$GITHUB_ENV"]
//
// --base: the current version on main (an edit); without it the pathway is scored as new.
// --base-sbgn, --base-minerva: the static SBGN-ML stored next to it (WPxx-sbgn.xml) and its provenance
//         (WPxx-minerva.json, written by scripts/minerva-convert). Used instead of converting the base
//         again when the provenance's gpml_sha256 matches the base GPML, so only the PR's GPML needs MINERVA.
// --env:  appends note_test_layout, status_test_layout and color_test_layout (as the other tests do).
// Thresholds: LAYOUT_MIN_METABOLITES, LAYOUT_MIN_PROCESSES, LAYOUT_NEW_MIN_SCORE, LAYOUT_MAX_DROP (see lib.mjs DEFAULTS).
// The scorer (core.js) is downloaded at a pinned commit and checked against its SHA-256; --core uses a local copy.
// Always exits 0 unless the arguments are wrong: a failed conversion is reported as SKIPPED.

import { createHash } from "node:crypto";
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { DOMParser } from "@xmldom/xmldom";
import { DEFAULTS, judge, markdownReport, scoreGpml } from "./lib.mjs";

const CORE_COMMIT = "c1f2ef7ba6df8ccaa68cf4365f687766dc01f2a9";
const CORE_URL = `https://raw.githubusercontent.com/elixir2026-project22/frontend-tool-pathway-scorer/${CORE_COMMIT}/build/core.js`;
const CORE_SHA256 = "63044dfbc94a38bbfbc8015ee49a96a8781d1780f1e3442d5f2e79d3c2d035cf";

const { values: args } = parseArgs({
  options: {
    pr: { type: "string" },
    base: { type: "string" },
    "base-sbgn": { type: "string" },
    "base-minerva": { type: "string" },
    core: { type: "string" },
    json: { type: "string" },
    markdown: { type: "string" },
    env: { type: "string" },
  },
});
if (!args.pr) {
  console.error("usage: node cli.mjs --pr <gpml> [--base <gpml>] [--json f] [--markdown f] [--env $GITHUB_ENV]");
  process.exit(2);
}

const num = (name, fallback) => (process.env[name] ? Number(process.env[name]) : fallback);
const opts = {
  minMetabolites: num("LAYOUT_MIN_METABOLITES", DEFAULTS.minMetabolites),
  minProcesses: num("LAYOUT_MIN_PROCESSES", DEFAULTS.minProcesses),
  newMinScore: num("LAYOUT_NEW_MIN_SCORE", DEFAULTS.newMinScore),
  maxDrop: num("LAYOUT_MAX_DROP", DEFAULTS.maxDrop),
};

async function loadCore() {
  let path = args.core && resolve(args.core);
  if (!path) {
    const res = await fetch(CORE_URL);
    if (!res.ok) throw new Error(`could not download the scorer: HTTP ${res.status}`);
    const text = await res.text();
    const sha = createHash("sha256").update(text).digest("hex");
    if (sha !== CORE_SHA256) throw new Error(`the scorer's SHA-256 is ${sha}, expected ${CORE_SHA256}`);
    path = join(tmpdir(), `layout-score-core-${CORE_COMMIT.slice(0, 7)}.cjs`);
    writeFileSync(path, text);
  }
  return createRequire(import.meta.url)(path);
}

// xmldom reports malformed XML through console; core.js then fails on the document, which scoreGpml catches.
const Parser = class extends DOMParser {
  constructor() {
    super({ onError: () => {} });
  }
};

let core = null;
let coreError = null;
try {
  core = await loadCore();
} catch (e) {
  coreError = e.message;
}

const read = (f) => readFileSync(f, "utf8");
const sha256 = (text) => createHash("sha256").update(text).digest("hex");

/** The stored SBGN-ML of the base version, if its provenance says it was made from exactly this GPML. */
function storedBaseLayout(baseGpml) {
  if (!args["base-sbgn"] || !args["base-minerva"] || !existsSync(args["base-sbgn"]) || !existsSync(args["base-minerva"])) return null;
  try {
    const prov = JSON.parse(read(args["base-minerva"]));
    if (prov.gpml_sha256 !== sha256(baseGpml) || !(prov.formats || {})["SBGN-ML"]) return null;
    return read(args["base-sbgn"]);
  } catch {
    return null;
  }
}

const pr = core ? await scoreGpml(core, read(args.pr), args.pr, Parser, opts) : { error: coreError };
let base = null;
if (core && args.base) {
  const baseGpml = read(args.base);
  const layout = storedBaseLayout(baseGpml);
  base = await scoreGpml(core, baseGpml, args.base, Parser, { ...opts, layout });
}
const verdict = judge(pr, base, opts);

console.log(`${verdict.status}: ${verdict.note}`);
if (args.json) writeFileSync(args.json, JSON.stringify({ pr, base, verdict, scorer: CORE_URL }, null, 2));
if (args.markdown) writeFileSync(args.markdown, markdownReport(pr, base, verdict));
if (args.env) {
  // The note is pasted into a single-quoted shell string and a Markdown table by the workflow:
  // keep a safe character set only (error messages may quote converter output).
  const oneLine = (s) => s.replace(/[^A-Za-z0-9 .,:;()/+\-=%]/g, " ").replace(/\s+/g, " ").trim();
  appendFileSync(
    args.env,
    `note_test_layout=${oneLine(verdict.note)}\nstatus_test_layout=${verdict.status}\ncolor_test_layout=${verdict.color}\n`,
  );
}
