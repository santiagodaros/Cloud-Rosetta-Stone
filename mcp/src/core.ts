/**
 * Lógica pura del MCP server: búsqueda y formato sobre el dataset publicado.
 * Sin I/O ni dependencias del SDK, para poder testearla con la suite del sitio.
 */

export type Locale = 'es' | 'en';
export type Localized = { es: string; en?: string };
export type Text = string | Localized;

export type Gotcha = {
  key: string;
  pattern: string;
  provider: string;
  id: string;
  severity: string;
  title: Localized;
  body: Localized;
  sources: string[];
  verified_at: string;
  exams: string[];
  url: Partial<Record<Locale, string>>;
};

export type Capability = {
  id: string;
  category: string;
  name: Text;
  description: Text;
  providers: Record<string, { services: { service: Text; docs: string; notes?: Text }[] } | { gap: Text; docs?: string }>;
  caveats: Text[];
};

export type Pattern = {
  id: string;
  title: Text;
  summary: Text;
  problem: Text;
  roles: ({ id: string; kind: 'actor'; label: Text } | { id: string; kind: 'capability'; capability: string; label: Text })[];
  implementations: Record<string, { bindings: Record<string, { service: Text; config?: Text } | { gap: Text }>; gotchas: { id: string }[] }>;
};

export type Exam = { code: string; provider: string; name: string; certification: string; status: string; retires_on?: string; replaced_by?: string; url: string; gotchas: string[] };

export type Concept = {
  id: string;
  category: string;
  name: Localized;
  description: Localized;
  providers: Record<string, { terms: { term: Text; docs: string }[]; explanation: Localized }>;
  caveats: { text: Localized; sources: string[] }[];
};

export type TerraformMapEntry = {
  id: string;
  title: Localized;
  match: 'one-to-one' | 'partial' | 'gap';
  resources: Record<string, string[]>;
  notes?: Localized;
  registry?: Record<string, string>;
};

export type PriceMeter = { id: string; provider: string; label: Localized; unit: string; docs: string; price: { unit_price: number; unit: string; source: string; as_of: string } | null };
export type FloorEntry = { monthly_usd: number; complete: boolean; as_of: string | null; items: { meter: string; count: number; monthly_usd: number | null }[] } | null;
export type Pricing = { regions?: Record<string, string>; meters: PriceMeter[]; floors: ({ pattern: string } & Record<string, FloorEntry | string>)[] };

export type DecisionOption = {
  id: string;
  provider: string;
  name: Text;
  meets: Record<string, 'yes' | 'no' | { value: 'yes' | 'no' | 'partial'; note: Localized }>;
  notes?: Localized;
  sources: string[];
  floor_monthly_usd: number | null;
  floor_complete: boolean;
};
export type Decision = { id: string; capability: string; title: Localized; intro: Localized; requirements: { id: string; label: Localized; hint?: Localized }[]; options: DecisionOption[]; verified_at: string };

export type Dataset = {
  schema_version: number;
  generated_at: string;
  attribution: string;
  gotchas: Gotcha[];
  patterns: Pattern[];
  capabilities: Capability[];
  exams: Exam[];
  concepts: Concept[];
  terraformMap: TerraformMapEntry[];
  pricing?: Pricing;
  decisions: Decision[];
};

/** Versión del dataset que entiende este server. */
export const SUPPORTED_SCHEMA_VERSION = 1;
export const STALE_AFTER_DAYS = 180;

export const t = (text: Text | undefined, lang: Locale): string =>
  text === undefined ? '' : typeof text === 'string' ? text : (lang === 'en' ? text.en : undefined) ?? text.es;

const normalize = (s: string) =>
  s.toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '');

const tokens = (s: string) => normalize(s).split(/[^a-z0-9]+/).filter((w) => w.length > 1);

export type SearchFilters = { provider?: string; severity?: string; exam?: string; pattern?: string };

/** Puntaje simple por términos: título pesa más que el cuerpo; todos los términos tienen que aparecer. */
export function searchGotchas(ds: Dataset, query: string, filters: SearchFilters = {}, limit = 10): Gotcha[] {
  const terms = tokens(query);
  const scored: { g: Gotcha; score: number }[] = [];
  for (const g of ds.gotchas) {
    if (filters.provider && g.provider !== filters.provider) continue;
    if (filters.severity && g.severity !== filters.severity) continue;
    if (filters.pattern && g.pattern !== filters.pattern) continue;
    if (filters.exam && !g.exams.includes(filters.exam.toUpperCase())) continue;
    const title = normalize(`${g.title.es} ${g.title.en ?? ''}`);
    const body = normalize(`${g.body.es} ${g.body.en ?? ''} ${g.key} ${g.exams.join(' ')}`);
    let score = 0;
    let all = true;
    for (const term of terms) {
      const inTitle = title.includes(term);
      const inBody = body.includes(term);
      if (!inTitle && !inBody) all = false;
      score += (inTitle ? 3 : 0) + (inBody ? 1 : 0);
    }
    if (terms.length === 0 || all) scored.push({ g, score });
  }
  return scored
    .sort((a, b) => b.score - a.score || a.g.key.localeCompare(b.g.key))
    .slice(0, limit)
    .map((s) => s.g);
}

export function findCapabilities(ds: Dataset, query: string): Capability[] {
  const terms = tokens(query);
  if (terms.length === 0) return [];
  return ds.capabilities.filter((c) => {
    const hay = normalize(
      [c.id, t(c.name, 'es'), t(c.name, 'en'), t(c.description, 'en'),
        ...Object.values(c.providers).flatMap((p) => ('gap' in p ? [t(p.gap, 'en')] : p.services.map((s) => `${t(s.service, 'es')} ${t(s.service, 'en')}`)))].join(' '),
    );
    return terms.every((term) => hay.includes(term));
  });
}

export function daysSince(iso: string, today = new Date()): number {
  const d = Date.parse(`${iso}T00:00:00Z`);
  const now = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  return Math.floor((now - d) / 86_400_000);
}

export function formatGotcha(g: Gotcha, lang: Locale, today = new Date()): string {
  const age = daysSince(g.verified_at, today);
  const fresh = age > STALE_AFTER_DAYS ? ` (verified ${age} days ago: re-verify before relying on it)` : '';
  return [
    `### ${t(g.title, lang)}`,
    `key: ${g.key} · cloud: ${g.provider} · severity: ${g.severity} · verified_at: ${g.verified_at}${fresh}${g.exams.length ? ` · exams: ${g.exams.join(', ')}` : ''}`,
    '',
    t(g.body, lang),
    '',
    `Sources: ${g.sources.join(' ')}`,
    g.url[lang] ? `Link: ${g.url[lang]}` : '',
  ].filter((l, i, a) => l !== '' || a[i - 1] !== '').join('\n');
}

export function formatCapability(c: Capability, lang: Locale): string {
  const lines = [`### ${t(c.name, lang)} (${c.id})`, t(c.description, lang), ''];
  for (const [provider, entry] of Object.entries(c.providers)) {
    lines.push('gap' in entry
      ? `- ${provider}: no direct equivalent. ${t(entry.gap, lang)}`
      : `- ${provider}: ${entry.services.map((s) => `${t(s.service, lang)} (${s.docs})`).join('; ')}`);
  }
  if (c.caveats.length) lines.push('', `Where the analogy breaks: ${c.caveats.map((x) => t(x, lang)).join(' ')}`);
  return lines.join('\n');
}

export function formatPattern(p: Pattern, ds: Dataset, lang: Locale, providers?: string[]): string {
  const clouds = (providers?.length ? providers : Object.keys(p.implementations)).filter((x) => p.implementations[x]);
  const lines = [`## ${t(p.title, lang)} (${p.id})`, t(p.summary, lang), '', `Problem: ${t(p.problem, lang)}`, '', '| Role | ' + clouds.join(' | ') + ' |', '|---|' + clouds.map(() => '---|').join('')];
  for (const role of p.roles) {
    if (role.kind === 'actor') continue;
    const cells = clouds.map((c) => {
      const b = p.implementations[c].bindings[role.id];
      return !b ? '' : 'gap' in b ? `no equivalent: ${t(b.gap, lang)}` : t(b.service, lang);
    });
    lines.push(`| ${t(role.label, lang)} | ${cells.join(' | ')} |`);
  }
  for (const c of clouds) {
    const gotchas = ds.gotchas.filter((g) => g.pattern === p.id && g.provider === c);
    lines.push('', `Fine print on ${c} (${gotchas.length}): ${gotchas.map((g) => `${t(g.title, lang)} [${g.key}]`).join('; ')}`);
  }
  return lines.join('\n');
}

export function checkSchema(ds: { schema_version?: number }): void {
  if (ds.schema_version !== SUPPORTED_SCHEMA_VERSION) {
    throw new Error(`Unsupported dataset schema_version ${ds.schema_version}; this server understands ${SUPPORTED_SCHEMA_VERSION}. Update letra-chica-mcp.`);
  }
}

export function findConcepts(ds: Dataset, query: string): Concept[] {
  const terms = tokens(query);
  if (terms.length === 0) return [];
  return ds.concepts.filter((c) => {
    const hay = normalize(
      [c.id, t(c.name, 'es'), t(c.name, 'en'), t(c.description, 'en'),
        ...Object.values(c.providers).flatMap((p) => p.terms.map((x) => `${t(x.term, 'es')} ${t(x.term, 'en')}`))].join(' '),
    );
    return terms.every((term) => hay.includes(term));
  });
}

export function formatConcept(c: Concept, lang: Locale): string {
  const lines = [`### ${t(c.name, lang)} (${c.id})`, t(c.description, lang), ''];
  for (const [provider, e] of Object.entries(c.providers)) {
    lines.push(`- ${provider} (${e.terms.map((x) => `${t(x.term, lang)} <${x.docs}>`).join(' → ')}): ${t(e.explanation, lang)}`);
  }
  for (const cv of c.caveats) lines.push('', `Where the analogy breaks: ${t(cv.text, lang)} Sources: ${cv.sources.join(' ')}`);
  return lines.join('\n');
}

/** Busca por nombre exacto de recurso (azurerm_*, aws_*, google_*) o por palabras del título. */
export function findTerraform(ds: Dataset, query: string): TerraformMapEntry[] {
  const q = query.trim().toLowerCase();
  const exact = ds.terraformMap.filter((e) => Object.values(e.resources).flat().some((r) => r === q || r.split('.')[0] === q));
  if (exact.length) return exact;
  const terms = tokens(query);
  return ds.terraformMap.filter((e) => {
    const hay = normalize(`${e.id} ${t(e.title, 'es')} ${t(e.title, 'en')} ${Object.values(e.resources).flat().join(' ')}`);
    return terms.length > 0 && terms.every((term) => hay.includes(term));
  });
}

export function formatTerraform(e: TerraformMapEntry, lang: Locale): string {
  const lines = [`### ${t(e.title, lang)} (${e.match})`];
  for (const [provider, refs] of Object.entries(e.resources)) {
    lines.push(`- ${provider}: ${refs.length ? refs.map((r) => (e.registry?.[r] ? `${r} <${e.registry[r]}>` : r)).join(', ') : 'no equivalent resource'}`);
  }
  if (e.notes) lines.push('', t(e.notes, lang));
  return lines.join('\n');
}

const usd = (n: number) => `USD ${n.toFixed(n < 100 ? 2 : 0)}`;

/** Piso mensual de lista sin tráfico, por patrón y nube (de /api/v1/pricing.json). */
export function formatFloors(ds: Dataset, lang: Locale, pattern?: string): string {
  if (!ds.pricing) return 'No pricing data published yet.';
  const meters = new Map(ds.pricing.meters.map((m) => [m.id, m]));
  const rows = ds.pricing.floors.filter((f) => !pattern || f.pattern === pattern);
  if (!rows.length) return `No price floor for "${pattern}". Known: ${ds.pricing.floors.map((f) => f.pattern).join(', ')}.`;
  const providers = ['azure', 'aws', 'gcp'];
  const regions = ds.pricing.regions ? providers.map((p) => `${p} ${ds.pricing!.regions![p]}`).join(', ') : '';
  const lines = [`Monthly list-price floor with zero traffic, USD, no discounts or taxes (${regions}).`, '', `| Pattern | ${providers.join(' | ')} |`, `|---|${providers.map(() => '---|').join('')}`];
  for (const f of rows) {
    lines.push(`| ${f.pattern} | ${providers.map((p) => { const e = f[p] as FloorEntry; return e ? `${e.complete ? '' : '≥ '}${usd(e.monthly_usd)}` : '—'; }).join(' | ')} |`);
  }
  if (pattern) {
    for (const p of providers) {
      const e = rows[0][p] as FloorEntry;
      if (!e || !e.items.length) continue;
      lines.push('', `${p} (prices as of ${e.as_of}):`);
      for (const it of e.items) {
        const m = meters.get(it.meter);
        lines.push(`- ${m ? t(m.label, lang) : it.meter} × ${it.count}: ${it.monthly_usd === null ? 'no price' : usd(it.monthly_usd)}${m?.price?.source === 'manual' ? ' (manual price)' : ''}${m ? ` <${m.docs}>` : ''}`);
      }
    }
  }
  return lines.join('\n');
}

export function findDecision(ds: Dataset, query: string): Decision | undefined {
  const q = normalize(query.trim());
  const exact = ds.decisions.find((d) => d.id === q || d.capability === q);
  if (exact) return exact;
  const terms = tokens(query);
  return ds.decisions.find((d) => {
    const hay = normalize(`${d.id} ${d.capability} ${t(d.title, 'es')} ${t(d.title, 'en')}`);
    return terms.length > 0 && terms.every((term) => hay.includes(term));
  });
}

const meetsValue = (m: DecisionOption['meets'][string]) => (typeof m === 'string' ? m : m.value);

/** Matriz requisito → opción, filtrada por los requisitos pedidos; marca la más barata que cumple por nube. */
export function formatDecision(d: Decision, lang: Locale, wanted: string[] = [], lenient = false): string {
  const unknown = wanted.filter((w) => !d.requirements.some((r) => r.id === w));
  const reqs = d.requirements.filter((r) => wanted.includes(r.id));
  const ok = (o: DecisionOption) => reqs.every((r) => { const v = meetsValue(o.meets[r.id]); return v === 'yes' || (lenient && v === 'partial'); });
  const lines = [`### ${t(d.title, lang)} (${d.id}, verified ${d.verified_at})`, t(d.intro, lang), '', `Requirements: ${d.requirements.map((r) => `${r.id} = ${t(r.label, lang)}`).join('; ')}`];
  if (unknown.length) lines.push(`Unknown requirement ids ignored: ${unknown.join(', ')}`);
  if (reqs.length) {
    lines.push('', `Cheapest option per cloud meeting ${reqs.map((r) => r.id).join(' + ')}${lenient ? ' (caveats count as met)' : ''}:`);
    for (const p of ['azure', 'aws', 'gcp']) {
      const best = d.options.filter((o) => o.provider === p && ok(o)).sort((a, b) => (a.floor_monthly_usd ?? Infinity) - (b.floor_monthly_usd ?? Infinity))[0];
      lines.push(`- ${p}: ${best ? `${t(best.name, lang)} — floor ${best.floor_monthly_usd === null ? 'n/a' : `${best.floor_complete ? '' : '≥ '}${usd(best.floor_monthly_usd)}/month`}` : 'no option meets all of them'}`);
    }
  }
  lines.push('', 'All options:');
  for (const o of d.options) {
    const cells = d.requirements.map((r) => {
      const m = o.meets[r.id];
      return `${r.id}: ${meetsValue(m)}${typeof m === 'string' ? '' : ` (${t(m.note, lang)})`}`;
    });
    lines.push(`- [${o.provider}] ${t(o.name, lang)}${reqs.length && !ok(o) ? ' — does not meet the request' : ''}`, `  ${cells.join('; ')}`);
    lines.push(`  Floor: ${o.floor_monthly_usd === null ? 'n/a' : `${usd(o.floor_monthly_usd)}/month`}. Sources: ${o.sources.join(' ')}`);
  }
  return lines.join('\n');
}
