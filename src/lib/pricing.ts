/**
 * Piso mensual de lista (F4-03) a partir de `content/pricing.yaml` + `content/prices.json`.
 * Puro: lo usan el sitio, el dataset, la matriz de decisión y los tests.
 */
import { HOURS_PER_MONTH, type FloorItem, type PriceEntry, type PriceMeter, type Prices, type Pricing, type PriceUnit, type Provider } from './schema.ts';

export type FloorLine = { meter: PriceMeter; count: number; price?: PriceEntry; monthly?: number };
export type Floor = {
  provider: Provider;
  region: string;
  /** Suma de las líneas con precio. Si `complete` es false, es una cota inferior. */
  total: number;
  complete: boolean;
  lines: FloorLine[];
  /** Fecha del precio más viejo usado. */
  asOf?: string;
  /** Alguna línea usa precio manual (sin API). */
  manual: boolean;
};

export const monthlyCost = (price: PriceEntry, count: number) =>
  price.unit_price * count * (price.unit === 'hour' ? HOURS_PER_MONTH : 1);

export function computeFloor(items: FloorItem[], provider: Provider, pricing: Pricing, prices: Prices | undefined): Floor {
  const lines = items.map((it): FloorLine => {
    const meter = pricing.meters.find((m) => m.id === it.meter);
    if (!meter) throw new Error(`meter inexistente: ${it.meter}`);
    const price = prices?.prices[it.meter];
    return { meter, count: it.count, price, monthly: price ? monthlyCost(price, it.count) : undefined };
  });
  const dates = lines.flatMap((l) => (l.price ? [l.price.as_of] : [])).sort();
  return {
    provider,
    region: pricing.regions[provider],
    total: lines.reduce((sum, l) => sum + (l.monthly ?? 0), 0),
    complete: lines.every((l) => l.price),
    lines,
    asOf: dates[0],
    manual: lines.some((l) => l.price?.source === 'manual'),
  };
}

export function patternFloor(patternId: string, provider: Provider, pricing: Pricing | undefined, prices: Prices | undefined): Floor | undefined {
  const items = pricing?.floors[patternId]?.[provider];
  return pricing && items ? computeFloor(items, provider, pricing, prices) : undefined;
}

/** "USD 12.41" / "USD 1,234" — siempre USD (precio de lista), con separadores del idioma. */
export function formatUsd(n: number, lang: 'es' | 'en'): string {
  const digits = n === 0 ? 0 : n < 100 ? 2 : 0;
  const num = new Intl.NumberFormat(lang === 'es' ? 'es-AR' : 'en-US', { minimumFractionDigits: digits, maximumFractionDigits: digits }).format(n);
  return `USD ${num}`;
}

/** "1 Hour", "1/Hour", "100 Hours", "1 GB/Month", "1/Month" → unidad normalizada y divisor. */
export function parseAzureUnit(u: string): { unit: PriceUnit; per: number } | undefined {
  const m = /^(\d+)\s*(K)?\s*\/?\s*(.+)$/.exec(u.trim());
  if (!m) return undefined;
  const per = Number(m[1]) * (m[2] ? 1000 : 1);
  const rest = m[3].toLowerCase().replace(/\s+/g, ' ');
  if (/^hours?$/.test(rest)) return { unit: 'hour', per };
  if (/^(days?)$/.test(rest)) return { unit: 'hour', per: per * 24 };
  if (/^months?$/.test(rest)) return { unit: 'month', per };
  if (/^gi?b\/months?$/.test(rest) || /^gi?b months?$/.test(rest)) return { unit: 'gb-month', per };
  return undefined;
}
