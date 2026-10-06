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
