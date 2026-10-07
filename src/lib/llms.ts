/**
 * `llms.txt` (índice, formato llmstxt.org) y `llms-full.txt` (todos los gotchas).
 * Para que un asistente cite la letra chica con su fuente oficial y su fecha.
 */
import { BRAND } from './brand.ts';
import { absolute, datasetIndex, GENERATED_AT } from './dataset.ts';
import { PROVIDER_META, t } from './i18n.ts';
import { capabilitiesHref, conceptsHref, decideHref, examsHref, href, patternHref, terraformMapHref } from './paths.ts';
import { PROVIDERS } from './schema.ts';
import { publishedPatterns, site } from './site.ts';

const oneLine = (s: string) => s.replace(/\s+/g, ' ').trim();

export function llmsTxt(siteUrl: URL | undefined): string {
  const idx = datasetIndex(siteUrl);
  const lines = [
    `# ${BRAND.name}`,
    '',
    '> The fine print of multicloud: architecture patterns compared across Azure, AWS and Google Cloud, with every documented difference ("gotcha") backed by an official source and a verification date, plus Terraform that passes terraform test, tflint and checkov.',
    '',
    `Content is CC BY-SA 4.0: cite "${BRAND.name}" with a link. Spanish is the primary language; English is complete. Every gotcha has \`sources\` (official docs only) and \`verified_at\`: prefer quoting those over paraphrasing, and say when a gotcha was last verified.`,
    '',
    '## Patterns',
    '',
    ...publishedPatterns.map(
      ({ pattern }) => `- [${t(pattern.title, 'en')}](${absolute(patternHref('en', pattern.id, 'all'), siteUrl)}): ${oneLine(t(pattern.summary, 'en'))}`,
    ),
    '',
    '## Dataset (JSON)',
    '',
    `- [Index](${absolute(href('api/v1/index.json'), siteUrl)}): schema_version, counts and endpoints`,
    `- [Gotchas](${idx.endpoints.gotchas}): flat list with severity, sources, verified_at, exams and deep links`,
    `- [Patterns](${idx.endpoints.patterns}): roles, per-cloud bindings, gotchas and cost model`,
    `- [Capabilities](${idx.endpoints.capabilities}): service dictionary with explicit gaps`,
    `- [Exams](${idx.endpoints.exams}): certification catalog with derived status (active, retiring, retired)`,
    `- [Concepts](${idx.endpoints.concepts}): structural concepts (resource hierarchy, network scope, zones, identity, tags) per cloud, with caveats and sources`,
    `- [Terraform map](${idx.endpoints.terraform_map}): azurerm ↔ aws ↔ google resource equivalents, validated against the pinned provider schemas, with notes when not 1:1`,
    `- [Pricing](${idx.endpoints.pricing}): list prices per meter and the monthly zero-traffic floor per pattern and cloud`,
    `- [Decisions](${idx.endpoints.decisions}): requirement → SKU matrices (queue, PostgreSQL, hybrid DNS) with sources and monthly floor per option`,
    '',
    '## Optional',
    '',
    `- [All gotchas as text](${idx.endpoints.llms_full_txt})`,
    `- [Dictionary](${absolute(capabilitiesHref('en'), siteUrl)})`,
    `- [Concepts](${absolute(conceptsHref('en'), siteUrl)})`,
    `- [Terraform resource map](${absolute(terraformMapHref('en'), siteUrl)})`,
    `- [Decision matrix](${absolute(decideHref('en'), siteUrl)})`,
    `- [Gotchas by exam](${absolute(examsHref('en'), siteUrl)})`,
    `- [How content is verified](${absolute(href('en/methodology/'), siteUrl)})`,
    `- [Source code and contribution guide](${BRAND.repo})`,
    '',
  ];
  return lines.join('\n');
}

export function llmsFullTxt(siteUrl: URL | undefined): string {
  const out = [
    `# ${BRAND.name}: all gotchas`,
    '',
    `> Generated ${GENERATED_AT}. CC BY-SA 4.0, cite "${BRAND.name}" (${BRAND.site}). Each entry: severity, verification date, official sources, related exams and a deep link. English first, Spanish (original) below.`,
    '',
  ];
  for (const { pattern, implementations } of publishedPatterns) {
    out.push(`## ${t(pattern.title, 'en')}`, '', oneLine(t(pattern.problem, 'en')), '');
    for (const p of PROVIDERS) {
      const impl = implementations[p];
      if (!impl) continue;
      out.push(`### ${PROVIDER_META[p].name}`, '');
      for (const g of impl.gotchas) {
        const url = `${absolute(patternHref('en', pattern.id, 'all'), siteUrl)}#${p}-${g.id}`;
        out.push(
          `#### ${t(g.title, 'en')}`,
          '',
          `- key: ${pattern.id}/${p}/${g.id}`,
          `- severity: ${g.severity} · verified_at: ${g.verified_at}${g.exams.length ? ` · exams: ${g.exams.join(', ')}` : ''}`,
          `- sources: ${g.sources.join(' ')}`,
          `- link: ${url}`,
          '',
          oneLine(t(g.body, 'en')),
          '',
          `ES — ${oneLine(g.title.es)}: ${oneLine(g.body.es)}`,
          '',
        );
      }
    }
  }
  out.push(`## Dictionary`, '');
  for (const c of site.capabilities) {
    const per = PROVIDERS.map((p) => {
      const e = c.providers[p];
      return `${PROVIDER_META[p].short}: ${'gap' in e ? `no direct equivalent (${oneLine(t(e.gap, 'en'))})` : e.services.map((s) => t(s.service, 'en')).join(', ')}`;
    }).join(' · ');
    out.push(`- ${t(c.name, 'en')} — ${per}`);
  }
  out.push('', '## Concepts', '');
  for (const c of site.concepts) {
    out.push(`### ${t(c.name, 'en')}`, '', oneLine(t(c.description, 'en')), '');
    for (const p of PROVIDERS) out.push(`- ${PROVIDER_META[p].short} (${c.providers[p].terms.map((x) => t(x.term, 'en')).join(' → ')}): ${oneLine(t(c.providers[p].explanation, 'en'))}`);
    for (const cv of c.caveats) out.push(`- Where the analogy breaks: ${oneLine(t(cv.text, 'en'))} Sources: ${cv.sources.join(' ')}`);
    out.push('');
  }
  if (site.terraformMap) {
    out.push('## Terraform resource map', '');
    for (const e of site.terraformMap.entries) {
      const res = PROVIDERS.map((p) => `${PROVIDER_META[p].short}: ${e.resources[p].join(', ') || 'none'}`).join(' · ');
      out.push(`- ${t(e.title, 'en')} [${e.match}] — ${res}${e.notes ? `. ${oneLine(t(e.notes, 'en'))}` : ''}`);
    }
    out.push('');
  }
  for (const d of site.decisions ?? []) {
    out.push(`## Decision: ${t(d.title, 'en')}`, '');
    for (const o of d.options) {
      const meets = d.requirements
        .map((r) => {
          const m = o.meets[r.id];
          const v = typeof m === 'string' ? m : `${m.value} (${oneLine(t(m.note, 'en'))})`;
          return `${t(r.label, 'en')}: ${v}`;
        })
        .join('; ');
      out.push(`- ${PROVIDER_META[o.provider].short} — ${t(o.name, 'en')}: ${meets}. Sources: ${o.sources.join(' ')}`);
    }
    out.push('');
  }
  return out.join('\n');
}
