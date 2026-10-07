import { describe, expect, it } from 'vitest';
import { crossValidate } from '../src/lib/content.ts';
import { computeFloor, formatUsd, monthlyCost, parseAzureUnit, patternFloor } from '../src/lib/pricing.ts';
import { PROVIDERS, type Pricing, type Prices } from '../src/lib/schema.ts';
import { publishedPatterns, site } from '../src/lib/site.ts';

const pricing: Pricing = {
  regions: { azure: 'eastus', aws: 'us-east-1', gcp: 'us-east1' },
  meters: [
    { id: 'a-hour', provider: 'azure', label: { es: 'Hora' }, unit: 'hour', docs: 'https://azure.microsoft.com/pricing/details/dns/' },
    { id: 'a-month', provider: 'azure', label: { es: 'Mes' }, unit: 'month', docs: 'https://azure.microsoft.com/pricing/details/dns/' },
    { id: 'a-gb', provider: 'azure', label: { es: 'GB' }, unit: 'gb-month', docs: 'https://azure.microsoft.com/pricing/details/dns/' },
  ],
  floors: {},
};
const prices: Prices = {
  generated_at: '2026-10-06T00:00:00Z',
  currency: 'USD',
  prices: {
    'a-hour': { unit_price: 0.01, unit: 'hour', source: 'api', as_of: '2026-10-05', ref: 'x' },
    'a-month': { unit_price: 0.5, unit: 'month', source: 'manual', as_of: '2026-10-01', ref: 'x' },
  },
};

describe('piso mensual (F4-03)', () => {
  it('lleva horas a mes con 730 h y suma por cantidad', () => {
    expect(monthlyCost(prices.prices['a-hour'], 2)).toBeCloseTo(14.6);
    const f = computeFloor([{ meter: 'a-hour', count: 2 }, { meter: 'a-month', count: 3 }], 'azure', pricing, prices);
    expect(f.total).toBeCloseTo(16.1);
    expect(f.complete).toBe(true);
    expect(f.manual).toBe(true);
    expect(f.asOf).toBe('2026-10-01');
  });

  it('sin precio el total es cota inferior', () => {
    const f = computeFloor([{ meter: 'a-hour', count: 1 }, { meter: 'a-gb', count: 32 }], 'azure', pricing, prices);
    expect(f.complete).toBe(false);
    expect(f.total).toBeCloseTo(7.3);
  });

  it('normaliza las unidades de la Retail Prices API de Azure', () => {
    expect(parseAzureUnit('1 Hour')).toEqual({ unit: 'hour', per: 1 });
    expect(parseAzureUnit('1/Hour')).toEqual({ unit: 'hour', per: 1 });
    expect(parseAzureUnit('100 Hours')).toEqual({ unit: 'hour', per: 100 });
    expect(parseAzureUnit('1/Month')).toEqual({ unit: 'month', per: 1 });
    expect(parseAzureUnit('1 GB/Month')).toEqual({ unit: 'gb-month', per: 1 });
    expect(parseAzureUnit('1/Day')).toEqual({ unit: 'hour', per: 24 });
    expect(parseAzureUnit('10K')).toBeUndefined();
  });

  it('formatea en USD con separadores del idioma', () => {
    expect(formatUsd(0, 'es')).toBe('USD 0');
    expect(formatUsd(12.4, 'es')).toBe('USD 12,40');
    expect(formatUsd(1234.5, 'en')).toBe('USD 1,235');
  });

  it('cada patrón publicado tiene piso en las tres nubes, y es 0 donde no hay costo fijo', () => {
    for (const { pattern, implementations } of publishedPatterns) {
      for (const p of PROVIDERS) {
        const f = patternFloor(pattern.id, p, site.pricing, site.prices);
        expect(f, `${pattern.id}/${p}`).toBeDefined();
        if ((implementations[p]?.cost.fixed_cost_drivers.length ?? 0) === 0) expect(f!.lines).toHaveLength(0);
        else expect(f!.lines.length).toBeGreaterThan(0);
      }
    }
  });
});

describe('matriz de decisión (F4-05)', () => {
  const decision = site.decisions![0];

  it('el contenido real valida y cubre las tres nubes', () => {
    expect(site.decisions!.length).toBeGreaterThanOrEqual(3);
    for (const d of site.decisions!) for (const p of PROVIDERS) expect(d.options.some((o) => o.provider === p)).toBe(true);
  });

  it('detecta requisitos sin evaluar y meters de otra nube', () => {
    const broken = {
      ...decision,
      options: decision.options.map((o, i) =>
        i === 0 ? { ...o, meets: Object.fromEntries(Object.entries(o.meets).slice(1)), floor: [{ meter: 'aws-alb', count: 1 }] } : o,
      ),
    };
    const issues = crossValidate({ ...site, decisions: [broken] }).filter((i) => i.file.includes('decisions')).map((i) => i.message);
    expect(decision.options[0].provider).not.toBe('aws');
    expect(issues.some((m) => m.includes('falta evaluar'))).toBe(true);
    expect(issues.some((m) => m.includes('es un meter de aws'))).toBe(true);
  });

  it('un piso vacío donde el patrón declara costo fijo es error', () => {
    const floors = structuredClone(site.pricing!.floors);
    floors['async-worker'].azure = [];
    const issues = crossValidate({ ...site, pricing: { ...site.pricing!, floors } }).map((i) => i.message);
    expect(issues.some((m) => m.includes('floors.async-worker.azure'))).toBe(true);
  });
});
