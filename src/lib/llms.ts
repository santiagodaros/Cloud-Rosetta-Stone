/**
 * `llms.txt` (índice, formato llmstxt.org) y `llms-full.txt` (todos los gotchas).
 * Para que un asistente cite la letra chica con su fuente oficial y su fecha.
 */
import { BRAND } from './brand.ts';
import { absolute, datasetIndex, GENERATED_AT } from './dataset.ts';
import { PROVIDER_META, t } from './i18n.ts';
import { capabilitiesHref, examsHref, href, patternHref } from './paths.ts';
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
    '',
    '## Optional',
    '',
    `- [All gotchas as text](${idx.endpoints.llms_full_txt})`,
    `- [Dictionary](${absolute(capabilitiesHref('en'), siteUrl)})`,
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
  out.push('');
  return out.join('\n');
}
