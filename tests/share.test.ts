import { describe, expect, it } from 'vitest';
import { comparisonMarkdown, gotchaMarkdown, staleIssueUrl } from '../src/lib/share.ts';
import { allGotchas, publishedPatterns } from '../src/lib/site.ts';

const { pattern, provider, gotcha } = allGotchas[0];
const ref = { pattern: pattern.id, provider, gotcha, url: `https://example.org/es/patterns/${pattern.id}/all/#${provider}-${gotcha.id}` };

describe('copiar como Markdown', () => {
  it('un gotcha lleva fuentes, fecha, link y atribución', () => {
    const md = gotchaMarkdown(ref, 'es');
    expect(md.split('\n')[0]).toMatch(/^\*\*\[(Azure|AWS|GCP)\] .+\*\* \(.+\)$/);
    for (const src of gotcha.sources) expect(md).toContain(`<${src}>`);
    expect(md).toContain(gotcha.verified_at);
    expect(md).toContain(`(${ref.url}) · CC BY-SA 4.0`);
  });

  it('una comparación arma la tabla de roles y enlaza cada gotcha', () => {
    const bundle = publishedPatterns.find((b) => b.pattern.id === 'hybrid-private-dns')!;
    const md = comparisonMarkdown(bundle, ['azure', 'aws'], 'en', 'https://example.org/en/patterns/hybrid-private-dns/azure-vs-aws/');
    expect(md).toMatch(/\| Role \| Azure \| AWS \|/);
    const roles = bundle.pattern.roles.filter((r) => r.kind === 'capability').length;
    expect(md.split('\n').filter((l) => l.startsWith('| ') && !l.startsWith('| Role')).length).toBe(roles);
    const gotchas = (bundle.implementations.azure?.gotchas.length ?? 0) + (bundle.implementations.aws?.gotchas.length ?? 0);
    expect(md.match(/^- \[(Azure|AWS)\] \[/gm)?.length).toBe(gotchas);
    expect(md).not.toMatch(/\[GCP\]/);
  });
});

describe('reportar desactualizado', () => {
  it('precarga el issue form con el gotcha', () => {
    const url = new URL(staleIssueUrl(ref));
    expect(url.pathname).toMatch(/\/issues\/new$/);
    expect(url.searchParams.get('template')).toBe('stale-gotcha.yml');
    expect(url.searchParams.get('location')).toContain(`${pattern.id} / ${provider} / ${gotcha.id}`);
  });
});
