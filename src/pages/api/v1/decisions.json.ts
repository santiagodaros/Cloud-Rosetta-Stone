import type { APIRoute } from 'astro';
import { envelope, jsonResponse } from '../../../lib/dataset.ts';
import { computeFloor } from '../../../lib/pricing.ts';
import { site } from '../../../lib/site.ts';

/** Dataset abierto: matrices de decisión (requisito → SKU) con piso mensual por opción (F4-05). */
export const GET: APIRoute = () =>
  jsonResponse(
    envelope({
      decisions: (site.decisions ?? []).map((d) => ({
        ...d,
        options: d.options.map((o) => {
          const f = site.pricing ? computeFloor(o.floor, o.provider, site.pricing, site.prices) : undefined;
          return { ...o, floor_monthly_usd: f ? Math.round(f.total * 100) / 100 : null, floor_complete: f?.complete ?? false };
        }),
      })),
    }),
  );
