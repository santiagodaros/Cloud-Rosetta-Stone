/**
 * "Copiar como Markdown" y "Reportar desactualizado" (F4-11, F4-12).
 * Todo se arma en build time: el cliente solo copia o navega.
 */
import { BRAND } from './brand.ts';
import { PROVIDER_META, t, ui, type Locale } from './i18n.ts';
import type { Gotcha, Provider } from './schema.ts';
import type { PatternBundle } from './content.ts';

export type GotchaRef = { pattern: string; provider: Provider; gotcha: Gotcha; url: string };

/** Bloque listo para pegar en un PR, un ADR o un ticket, con atribución CC BY-SA. */
export function gotchaMarkdown({ provider, gotcha: g, url }: GotchaRef, lang: Locale): string {
  const s = ui(lang);
  const sources = g.sources.map((src) => `<${src}>`).join(' · ');
  return [
    `**[${PROVIDER_META[provider].short}] ${t(g.title, lang)}** (${s.severity[g.severity]})`,
    '',
    t(g.body, lang).replace(/\s+/g, ' ').trim(),
    '',
    `- ${s.mdSources}: ${sources}`,
    `- ${s.mdVerified}: ${g.verified_at}`,
    `- ${s.mdVia} [${BRAND.name}](${url}) · CC BY-SA 4.0`,
  ].join('\n');
}

/** Issue form `stale-gotcha.yml` con el gotcha ya identificado. */
export function staleIssueUrl({ pattern, provider, gotcha: g, url }: GotchaRef): string {
  const q = new URLSearchParams({
    template: 'stale-gotcha.yml',
    title: `[freshness] ${pattern} / ${provider} / ${g.id}`,
    location: `${pattern} / ${provider} / ${g.id} — ${url}`,
  });
  return `${BRAND.repo}/issues/new?${q}`;
}

/** Comparación completa (roles × nubes + letra chica) para pegar en un ADR o una propuesta. */
export function comparisonMarkdown(bundle: PatternBundle, providers: Provider[], lang: Locale, url: string): string {
  const s = ui(lang);
  const { pattern, implementations } = bundle;
  const cell = (x: string) => x.replace(/\|/g, '\\|');
  const lines = [
    `### ${t(pattern.title, lang)}`,
    '',
    t(pattern.summary, lang),
    '',
    `| ${s.role} | ${providers.map((p) => PROVIDER_META[p].short).join(' | ')} |`,
    `|---|${providers.map(() => '---|').join('')}`,
  ];
  for (const role of pattern.roles) {
    if (role.kind !== 'capability') continue;
    const cells = providers.map((p) => {
      const b = implementations[p]?.bindings[role.id];
      return !b ? '' : 'gap' in b ? `_${s.gap}_` : cell(t(b.service, lang));
    });
    lines.push(`| ${cell(t(role.label, lang))} | ${cells.join(' | ')} |`);
  }
  lines.push('', `**${s.gotchas}**`, '');
  for (const p of providers) {
    for (const g of implementations[p]?.gotchas ?? []) {
      lines.push(`- [${PROVIDER_META[p].short}] [${t(g.title, lang)}](${url.replace(/#.*$/, '')}#${p}-${g.id}) (${s.mdVerified.toLowerCase()} ${g.verified_at})`);
    }
  }
  lines.push('', `${s.mdVia} [${BRAND.name}](${url}) · CC BY-SA 4.0`);
  return lines.join('\n');
}

/** Snippet `<iframe>` para embeber un widget (F4-18). El widget trae su propia atribución. */
export function embedSnippet(src: string, title: string, height: number): string {
  const esc = (x: string) => x.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
  return `<iframe src="${esc(src)}" title="${esc(title)}" width="100%" height="${height}" style="border:0;max-width:720px" loading="lazy"></iframe>`;
}
