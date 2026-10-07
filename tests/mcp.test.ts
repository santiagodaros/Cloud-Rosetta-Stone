import { describe, expect, it } from 'vitest';
import { checkSchema, findCapabilities, findConcepts, findDecision, findTerraform, formatDecision, formatFloors, formatGotcha, formatPattern, formatTerraform, searchGotchas, type Dataset } from '../mcp/src/core.ts';
import { computeFloor, patternFloor } from '../src/lib/pricing.ts';
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
  concepts: site.concepts,
  terraformMap: site.terraformMap?.entries ?? [],
  pricing: {
    regions: site.pricing!.regions,
    meters: site.pricing!.meters.map((m) => ({ ...m, price: site.prices?.prices[m.id] ?? null })),
    floors: publishedPatterns.map(({ pattern }) => ({
      pattern: pattern.id,
      ...Object.fromEntries((['azure', 'aws', 'gcp'] as const).map((p) => {
        const f = patternFloor(pattern.id, p, site.pricing, site.prices)!;
        return [p, { monthly_usd: f.total, complete: f.complete, as_of: f.asOf ?? null, items: f.lines.map((l) => ({ meter: l.meter.id, count: l.count, monthly_usd: l.monthly ?? null })) }];
      })),
    })),
  },
  decisions: (site.decisions ?? []).map((d) => ({
    ...d,
    options: d.options.map((o) => {
      const f = computeFloor(o.floor, o.provider, site.pricing!, site.prices);
      return { ...o, floor_monthly_usd: f.total, floor_complete: f.complete };
    }),
  })),
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

  it('encuentra conceptos y equivalentes de Terraform', () => {
    expect(findConcepts(ds, 'availability zones').map((c) => c.id)).toContain('availability-zones');
    expect(findTerraform(ds, 'azurerm_private_endpoint').map((e) => e.id)).toEqual(['private-endpoint']);
    expect(findTerraform(ds, 'google_storage_bucket').map((e) => e.id)).toEqual(expect.arrayContaining(['object-storage', 'object-lifecycle']));
    expect(formatTerraform(findTerraform(ds, 'peering')[0], 'en')).toMatch(/aws_vpc_peering_connection/);
  });

  it('rechaza un dataset con otra schema_version', () => {
    expect(() => checkSchema({ schema_version: 2 })).toThrow(/schema_version/);
  });

  it('piso mensual: tabla general y desglose por patrón', () => {
    const all = formatFloors(ds, 'en');
    expect(all).toMatch(/\| hybrid-private-dns \| USD 363 \| USD 365 \| USD 0\.40 \|/);
    const one = formatFloors(ds, 'en', 'private-web-api');
    expect(one).toMatch(/aws \(prices as of \d{4}-\d{2}-\d{2}\):/);
    expect(one).toContain('(manual price)');
  });

  it('matriz de decisión: busca por id o capability y elige la más barata que cumple', () => {
    expect(findDecision(ds, 'dns-forwarding')?.id).toBe('hybrid-dns');
    const d = findDecision(ds, 'message-queue')!;
    const out = formatDecision(d, 'en', ['fifo', 'private-only']);
    expect(out).toMatch(/- azure: Service Bus Premium/);
    expect(out).toMatch(/- aws: no option meets all of them/);
    expect(formatDecision(d, 'en', ['fifo', 'private-only'], true)).toMatch(/- aws: Amazon SQS FIFO/);
    expect(formatDecision(d, 'en', ['nope'])).toContain('Unknown requirement ids ignored: nope');
  });
});
