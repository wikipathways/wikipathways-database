// Layout score of a GPML pathway, by the layout rules of BioHackathon Europe 2026 project 22
// (https://github.com/elixir2026-project22/frontend-tool-pathway-scorer, build/core.js).
//
// core.js does not read GPML: the GPML is first converted to SBGN-ML by MINERVA
// (https://minerva.pages.uni.lu/api/19.0/converter.html), which turns GPML anchors into process
// nodes with consumption / production / catalysis arcs, as the rules need.
//
// No Node-specific imports here, so the same module runs in a browser (for testing) and in Node (cli.mjs).

export const MINERVA = "https://minerva-service.lcsb.uni.lu/minerva/api/convert";

// Defaults for the verdict; each can be overridden by an environment variable in cli.mjs.
export const DEFAULTS = {
  minMetabolites: 6, // GPML DataNodes of Type "Metabolite": fewer than this, the pathway isn't scored (rules are for metabolic maps)
  minProcesses: 3, // fewer reactions than this after conversion: the rules don't apply
  newMinScore: 50, // new pathway: REVIEW REQUIRED below this overall score
  maxDrop: 5, // edited pathway: REVIEW REQUIRED if the overall score drops by this much or more
};

/** Convert GPML text to another format with MINERVA's converter API. */
export async function convertGpml(gpml, { to = "SBGN-ML", endpoint = MINERVA, fetchImpl = fetch, timeoutMs = 120000 } = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetchImpl(`${endpoint}/GPML:${to}`, {
      method: "POST",
      headers: { "Content-Type": "text/plain" },
      body: gpml,
      signal: ctrl.signal,
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`MINERVA conversion failed: HTTP ${res.status}`);
    return text;
  } finally {
    clearTimeout(timer);
  }
}

/** Score a layout file (SBGN-ML, SBML Layout, ...) with core.js. */
export function scoreLayout(core, text, name, DOMParserImpl, opts = {}) {
  const minProcesses = opts.minProcesses ?? DEFAULTS.minProcesses;
  const model = core.parseText(text, name, DOMParserImpl);
  const { row } = core.scoreModel(model);
  const counts = { glyphs: row.glyphs, arcs: row.arcs, processes: row.processes, metabolites: row.metabolites };
  if ((row.processes || 0) < minProcesses) {
    return { applicable: false, reason: `${row.processes || 0} reactions (< ${minProcesses}): layout rules for metabolic maps do not apply`, counts };
  }
  const ev = core.evaluate(row);
  return {
    applicable: true,
    overall: ev.overall,
    hardPass: ev.hardPass,
    hardTotal: ev.hardTotal,
    rules: ev.rules.map((r) => ({ id: r.id, name: r.name, kind: r.kind, score: r.score, status: r.status, value: r.value, unit: r.unit || "" })),
    counts,
  };
}

/** Number of GPML DataNodes of Type "Metabolite". */
export function countMetabolites(gpml, DOMParserImpl) {
  const doc = new DOMParserImpl().parseFromString(gpml, "application/xml");
  const nodes = Array.from(doc.getElementsByTagName("*")).filter(
    (e) => (e.localName || e.nodeName) === "DataNode" && e.getAttribute("Type") === "Metabolite",
  );
  return nodes.length;
}

/**
 * Full pipeline for one GPML text: check that it is a metabolic pathway, convert (unless ``opts.layout``
 * gives an already converted SBGN-ML text, e.g. the static copy stored next to the GPML), then score.
 * Never throws: errors come back as { error }.
 */
export async function scoreGpml(core, gpml, name, DOMParserImpl, opts = {}) {
  try {
    const minMetabolites = opts.minMetabolites ?? DEFAULTS.minMetabolites;
    const metabolites = countMetabolites(gpml, DOMParserImpl);
    if (metabolites < minMetabolites) {
      return { applicable: false, reason: `${metabolites} metabolites (layout rules apply to pathways with more than ${minMetabolites - 1})`, counts: { gpmlMetabolites: metabolites } };
    }
    const layout = opts.layout || (await (opts.convert || convertGpml)(gpml, opts));
    const res = scoreLayout(core, layout, name, DOMParserImpl, opts);
    res.counts.gpmlMetabolites = metabolites;
    res.source = opts.layout ? "stored" : "minerva";
    return res;
  } catch (e) {
    return { error: String(e && e.message ? e.message : e) };
  }
}

const passedHard = (res) => new Set(res.rules.filter((r) => r.kind === "hard" && r.status === "pass").map((r) => r.id));

/**
 * The test's verdict, for the PR's "Automated Testing" table.
 * Returns { status: PASS | REVIEW REQUIRED | SKIPPED, color, note } (note: one line, no "|").
 */
export function judge(pr, base, opts = {}) {
  const newMinScore = opts.newMinScore ?? DEFAULTS.newMinScore;
  const maxDrop = opts.maxDrop ?? DEFAULTS.maxDrop;
  const skip = (note) => ({ status: "SKIPPED", color: "gray", note });

  if (pr.error) return skip(`Layout not scored: ${pr.error}.`);
  if (!pr.applicable) return skip(`Layout not scored: ${pr.reason}.`);
  const score = `Layout score ${pr.overall}/100, hard rules ${pr.hardPass}/${pr.hardTotal}`;

  if (base && base.applicable && !base.error) {
    const delta = pr.overall - base.overall;
    const lost = [...passedHard(base)].filter((id) => !passedHard(pr).has(id));
    const lostNames = pr.rules.filter((r) => lost.includes(r.id)).map((r) => r.name.toLowerCase());
    const change = `${delta >= 0 ? "+" : ""}${delta} vs. current version (${base.overall})`;
    if (delta <= -maxDrop || lost.length) {
      const why = lost.length ? `; no longer passes: ${lostNames.join(", ")}` : "";
      return { status: "REVIEW REQUIRED", color: "red", note: `${score}, ${change}${why}.` };
    }
    return { status: "PASS", color: "green", note: `${score}, ${change}.` };
  }

  if (pr.overall < newMinScore) {
    return { status: "REVIEW REQUIRED", color: "red", note: `${score} (below ${newMinScore}).` };
  }
  return { status: "PASS", color: "green", note: `${score}.` };
}

/** A Markdown report: per rule, the PR's score and value, and the current version's where there is one. */
export function markdownReport(pr, base, verdict) {
  const lines = ["## Layout score", "", `**${verdict.status}**: ${verdict.note}`, ""];
  if (pr.applicable && !pr.error) {
    const hasBase = base && base.applicable && !base.error;
    const byId = hasBase ? Object.fromEntries(base.rules.map((r) => [r.id, r])) : {};
    lines.push(hasBase ? "| Rule | Type | This PR | Current version |" : "| Rule | Type | Score |");
    lines.push(hasBase ? "|---|---|---|---|" : "|---|---|---|");
    const cell = (r) => (r && r.score !== null ? `${r.score} (${r.value}${r.unit ? " " + r.unit : ""})` : "n/a");
    for (const r of pr.rules) {
      const kind = r.kind === "hard" ? "required" : "recommended";
      lines.push(hasBase ? `| ${r.name} | ${kind} | ${cell(r)} | ${cell(byId[r.id])} |` : `| ${r.name} | ${kind} | ${cell(r)} |`);
    }
    lines.push(
      "",
      `Scored after conversion to SBGN-ML by MINERVA (${pr.counts.processes} reactions; ${pr.counts.gpmlMetabolites} metabolites in the GPML)` +
        (base && base.source === "stored" ? "; the current version from its stored SBGN-ML. " : ". ") +
        "Rules and thresholds: [BioHackathon 2026 project 22 pathway layout scorer](https://github.com/elixir2026-project22/frontend-tool-pathway-scorer); " +
        "they were designed for metabolic maps and are first proposals.",
    );
  }
  return lines.join("\n") + "\n";
}
