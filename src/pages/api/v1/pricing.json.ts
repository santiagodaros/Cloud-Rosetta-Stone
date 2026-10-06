import type { APIRoute } from 'astro';
import { envelope, jsonResponse } from '../../../lib/dataset.ts';
import { patternFloor } from '../../../lib/pricing.ts';
import { PROVIDERS } from '../../../lib/schema.ts';
import { publishedPatterns, site } from '../../../lib/site.ts';

/** Dataset abierto: precios de lista por meter y piso mensual por patrón y nube (F4-03). */
export const GET: APIRoute = () =>
  jsonResponse(
    envelope({
      currency: 'USD',
      regions: site.pricing?.regions,
      prices_generated_at: site.prices?.generated_at,
      meters: (site.pricing?.meters ?? []).map((m) => ({ id: m.id, provider: m.provider, label: m.label, unit: m.unit, docs: m.docs, price: site.prices?.prices[m.id] ?? null })),
      floors: publishedPatterns.map(({ pattern }) => ({
        pattern: pattern.id,
        ...Object.fromEntries(
          PROVIDERS.map((p) => {
            const f = patternFloor(pattern.id, p, site.pricing, site.prices);
            return [p, f ? { monthly_usd: Math.round(f.total * 100) / 100, complete: f.complete, as_of: f.asOf ?? null, items: f.lines.map((l) => ({ meter: l.meter.id, count: l.count, monthly_usd: l.monthly === undefined ? null : Math.round(l.monthly * 100) / 100 })) } : null];
          }),
        ),
      })),
    }),
  );
