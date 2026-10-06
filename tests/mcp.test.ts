import { describe, expect, it } from 'vitest';
import { checkSchema, findCapabilities, formatGotcha, formatPattern, searchGotchas, type Dataset } from '../mcp/src/core.ts';
import { flatGotchas } from '../src/lib/dataset.ts';
import { publishedPatterns, site } from '../src/lib/site.ts';

// El mismo shape que publica /api/v1/*.json, armado desde el contenido real.
const ds = {
  schema_version: 1,
  generated_at: '2026-10-06T00:00:00Z',
  attribution: 'Letra Chica',
  gotchas: flatGotchas(new URL('https://example.org/')),
  patterns: publishedPatterns.map(({ pattern, implementations }) => ({ ...pattern, implementations })),
  capabilities: site.capabilities,
  exams: site.exams.map((e) => ({ ...e, status: 'active', gotchas: [] })),
} as unknown as Dataset;

describe('mcp core', () => {
  it('busca en español e inglés, sin tildes, y exige todos los términos', () => {
    const en = searchGotchas(ds, 'filter prefix container');
    expect(en[0].key).toBe('object-storage-ttl/azure/prefix-includes-container');
    const es = searchGotchas(ds, 'prefijo contenedor');
    expect(es.map((g) => g.key)).toContain('object-storage-ttl/azure/prefix-includes-container');
    expect(searchGotchas(ds, 'resolución')).toEqual(searchGotchas(ds, 'resolucion'));
    expect(searchGotchas(ds, 'lifecycle zzzzzz')).toEqual([]);
  });

  it('aplica filtros por nube, severidad y examen', () => {
    for (const g of searchGotchas(ds, '', { provider: 'gcp', severity: 'networking' }, 50)) {
      expect(g.provider).toBe('gcp');
      expect(g.severity).toBe('networking');
    }
    expect(searchGotchas(ds, '', { exam: 'ans-c01' }, 50).every((g) => g.exams.includes('ANS-C01'))).toBe(true);
  });

  it('cada resultado lleva fuente, fecha y link', () => {
    const text = formatGotcha(searchGotchas(ds, 'oidc')[0], 'en', new Date('2026-10-06'));
    expect(text).toMatch(/verified_at: \d{4}-\d{2}-\d{2}/);
    expect(text).toMatch(/Sources: https:\/\//);
    expect(text).toMatch(/Link: https:\/\/example\.org\//);
  });

  it('marca los gotchas vencidos', () => {
    const text = formatGotcha(ds.gotchas[0], 'en', new Date('2027-12-31'));
    expect(text).toMatch(/re-verify/);
  });

  it('encuentra capabilities y muestra los huecos', () => {
    expect(findCapabilities(ds, 'private dns').map((c) => c.id)).toContain('private-dns');
    expect(findCapabilities(ds, 'data perimeter').length).toBeGreaterThan(0);
  });

  it('compara un patrón en las nubes pedidas', () => {
    const p = ds.patterns.find((x) => x.id === 'hybrid-private-dns')!;
    const text = formatPattern(p, ds, 'en', ['azure', 'aws']);
    expect(text).toMatch(/\| Role \| azure \| aws \|/);
    expect(text).not.toMatch(/Fine print on gcp/);
  });

  it('rechaza un dataset con otra schema_version', () => {
    expect(() => checkSchema({ schema_version: 2 })).toThrow(/schema_version/);
  });
});
