/**
 * Job de precios de lista (F4-03): resuelve cada meter de `content/pricing.yaml` contra la
 * API pública de su nube y escribe `content/prices.json`.
 *
 *   pnpm prices:fetch                 # resuelve y escribe (si algo cambió)
 *   pnpm prices:fetch --check         # resuelve y falla si algún selector no da exactamente un precio
 *   pnpm prices:fetch --providers aws # solo esas nubes (las demás se copian del prices.json actual)
 *   pnpm prices:fetch --check --list "Service Bus"   # además lista los meters de ese servicio de Azure
 *
 * - Azure: Retail Prices API (pública, sin auth).
 * - AWS: Price List bulk API (pública, sin auth), un offer file por servicio y región.
 * - GCP: Cloud Billing Catalog API. Pide API key (`GCP_BILLING_API_KEY`); sin key se usa el
 *   precio `manual` del meter, marcado como tal en el sitio.
 *
 * Corre en CI (semanal), nunca en runtime: el sitio solo lee el JSON versionado.
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { parse as parseYaml } from 'yaml';
import { z } from 'zod';
import { parseAzureUnit } from '../src/lib/pricing.ts';
import { PROVIDERS, Prices, Pricing, type PriceEntry, type PriceMeter, type PriceUnit, type Provider } from '../src/lib/schema.ts';

const root = process.cwd();
const args = process.argv.slice(2);
const check = args.includes('--check');
const list = args.includes('--list') ? args[args.indexOf('--list') + 1] : undefined;
const only = args.includes('--providers') ? (args[args.indexOf('--providers') + 1].split(',') as Provider[]) : [...PROVIDERS];
const pricesFile = join(root, 'content/prices.json');
const today = new Date().toISOString().slice(0, 10);

const pricing = Pricing.parse(parseYaml(readFileSync(join(root, 'content/pricing.yaml'), 'utf8')));
const previous = existsSync(pricesFile) ? Prices.parse(JSON.parse(readFileSync(pricesFile, 'utf8'))) : undefined;

type Resolved = { unit_price: number; unit: PriceUnit; ref: string };
class ResolveError extends Error {}

async function getJson(url: string): Promise<unknown> {
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(url, { headers: { accept: 'application/json' } });
    if (res.ok) return res.json();
    if (attempt >= 4 || (res.status < 500 && res.status !== 429)) throw new Error(`${res.status} ${res.statusText} — ${url.replace(/key=[^&]+/, 'key=***')}`);
    await new Promise((r) => setTimeout(r, 2 ** attempt * 1000));
  }
}

const AWS_UNITS: Record<string, PriceUnit> = { hrs: 'hour', hours: 'hour', hour: 'hour', 'gb-mo': 'gb-month', month: 'month', mo: 'month' };
const GCP_UNITS: Record<string, PriceUnit> = { h: 'hour', mo: 'month', 'GiBy.mo': 'gb-month', 'GiBy.h': 'hour' };

// ---------------------------------------------------------------------------
// Azure
// ---------------------------------------------------------------------------

const AzureItem = z.looseObject({
  serviceName: z.string(),
  productName: z.string(),
  skuName: z.string(),
  meterName: z.string(),
  unitOfMeasure: z.string(),
  retailPrice: z.number(),
  tierMinimumUnits: z.number(),
  type: z.string(),
  armSkuName: z.string().optional(),
  armRegionName: z.string(),
});
type AzureItem = z.infer<typeof AzureItem>;
const azureCache = new Map<string, Promise<AzureItem[]>>();

/** `region` null = todas las regiones (solo para --list). */
function azureItems(service: string, region: string | null = pricing.regions.azure): Promise<AzureItem[]> {
  const key = `${service}@${region}`;
  if (!azureCache.has(key)) {
    azureCache.set(
      key,
      (async () => {
        const filter = `serviceName eq '${service}'${region === null ? '' : ` and armRegionName eq '${region}'`} and priceType eq 'Consumption'`;
        let url: string | null = `https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview&$filter=${encodeURIComponent(filter)}`;
        const items: AzureItem[] = [];
        while (url) {
          const page = z.looseObject({ Items: z.array(AzureItem), NextPageLink: z.string().nullable() }).parse(await getJson(url));
          items.push(...page.Items);
          url = page.NextPageLink;
        }
        return items;
      })(),
    );
  }
  return azureCache.get(key)!;
}

async function resolveAzure(m: PriceMeter): Promise<Resolved> {
  const sel = m.azure!;
  const all = await azureItems(sel.service, sel.region ?? pricing.regions.azure);
  let hits = all.filter((i) => Object.entries(sel.match).every(([k, v]) => String((i as Record<string, unknown>)[k]) === v));
  // Escalonados (ej. zonas DNS: 0-25, 25+): el piso usa el primer escalón.
  if (hits.length > 1) hits = hits.filter((i) => i.tierMinimumUnits === 0);
  if (hits.length !== 1) {
    const near = all
      .filter((i) => Object.entries(sel.match).some(([k, v]) => String((i as Record<string, unknown>)[k]) === v))
      .map((i) => `    ${i.productName} | ${i.skuName} | ${i.meterName} | ${i.unitOfMeasure} | ${i.retailPrice} | tier ${i.tierMinimumUnits}`);
    throw new ResolveError(`${hits.length} coincidencias en "${sel.service}" (${all.length} ítems). Candidatos (productName | skuName | meterName | unit | price):\n${[...new Set(near)].slice(0, 40).join('\n')}`);
  }
  const it = hits[0];
  const u = parseAzureUnit(it.unitOfMeasure);
  if (!u) throw new ResolveError(`unidad desconocida "${it.unitOfMeasure}"`);
  return { unit_price: it.retailPrice / u.per, unit: u.unit, ref: `${it.productName} / ${it.skuName} / ${it.meterName} (${it.unitOfMeasure})` };
}

// ---------------------------------------------------------------------------
// AWS
// ---------------------------------------------------------------------------

type AwsOffer = {
  products: Record<string, { productFamily?: string; attributes: Record<string, string> }>;
  terms: { OnDemand: Record<string, Record<string, { priceDimensions: Record<string, { unit: string; beginRange?: string; pricePerUnit: { USD?: string }; description: string }> }>> };
};
const awsCache = new Map<string, Promise<AwsOffer>>();

function awsOffer(offer: string): Promise<AwsOffer> {
  if (!awsCache.has(offer)) {
    awsCache.set(offer, getJson(`https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/${offer}/current/${pricing.regions.aws}/index.json`) as Promise<AwsOffer>);
  }
  return awsCache.get(offer)!;
}

async function resolveAws(m: PriceMeter): Promise<Resolved> {
  const sel = m.aws!;
  const data = await awsOffer(sel.offer);
  const field = (p: AwsOffer['products'][string], k: string) => (k === 'productFamily' ? p.productFamily : p.attributes[k]);
  const hits = Object.entries(data.products).filter(([, p]) => Object.entries(sel.match).every(([k, v]) => field(p, k) === v));
  if (hits.length !== 1) {
    const near = hits.slice(0, 20).map(([sku, p]) => `    ${sku} ${JSON.stringify(p.attributes)}`);
    throw new ResolveError(`${hits.length} productos en ${sel.offer} con ${JSON.stringify(sel.match)}\n${near.join('\n')}`);
  }
  const [sku] = hits[0];
  const dims = Object.values(data.terms.OnDemand[sku] ?? {}).flatMap((t) => Object.values(t.priceDimensions));
  const dim = dims.length === 1 ? dims[0] : dims.find((d) => d.beginRange === '0');
  if (!dim) throw new ResolveError(`${sku}: ${dims.length} dimensiones de precio on-demand`);
  const unit = AWS_UNITS[dim.unit.toLowerCase()];
  if (!unit) throw new ResolveError(`${sku}: unidad desconocida "${dim.unit}"`);
  return { unit_price: Number(dim.pricePerUnit.USD), unit, ref: `${sel.offer} ${sku}: ${dim.description}` };
}

// ---------------------------------------------------------------------------
// GCP
// ---------------------------------------------------------------------------

const gcpKey = process.env.GCP_BILLING_API_KEY;
let gcpServices: Promise<Map<string, string>> | undefined;
const gcpSkus = new Map<string, Promise<GcpSku[]>>();
type GcpSku = {
  description: string;
  serviceRegions: string[];
  category: { usageType: string };
  pricingInfo: { pricingExpression: { usageUnit: string; tieredRates: { startUsageAmount: number; unitPrice: { units?: string; nanos?: number } }[] } }[];
};

async function gcpPaged<T>(url: string, key: string): Promise<T[]> {
  const out: T[] = [];
  let token = '';
  do {
    const page = (await getJson(`${url}${url.includes('?') ? '&' : '?'}key=${gcpKey}&pageSize=5000${token ? `&pageToken=${token}` : ''}`)) as Record<string, unknown>;
    out.push(...((page[key] as T[]) ?? []));
    token = (page.nextPageToken as string) ?? '';
  } while (token);
  return out;
}

const inRegion = (s: GcpSku) => s.serviceRegions.includes(pricing.regions.gcp) || s.serviceRegions.includes('global');

async function resolveGcp(m: PriceMeter): Promise<Resolved> {
  const sel = m.gcp!;
  gcpServices ??= gcpPaged<{ name: string; displayName: string }>('https://cloudbilling.googleapis.com/v1/services', 'services').then(
    (s) => new Map(s.map((x) => [x.displayName, x.name])),
  );
  const service = (await gcpServices).get(sel.service);
  if (!service) throw new ResolveError(`servicio "${sel.service}" no está en el catálogo`);
  if (!gcpSkus.has(service)) gcpSkus.set(service, gcpPaged<GcpSku>(`https://cloudbilling.googleapis.com/v1/${service}/skus?currencyCode=USD`, 'skus'));
  const all = await gcpSkus.get(service)!;
  const hits = all.filter((s) => s.description === sel.description && s.category.usageType === 'OnDemand' && inRegion(s));
  if (hits.length !== 1) {
    const words = sel.description.split(/\s+/).slice(0, 3).join(' ');
    const near = all.filter((s) => s.description.includes(words) && inRegion(s)).map((s) => `    ${s.description} [${s.category.usageType}]`);
    throw new ResolveError(`${hits.length} SKUs en "${sel.service}". Parecidos:\n${[...new Set(near)].slice(0, 30).join('\n')}`);
  }
  const expr = hits[0].pricingInfo[0].pricingExpression;
  const unit = GCP_UNITS[expr.usageUnit];
  if (!unit) throw new ResolveError(`unidad desconocida "${expr.usageUnit}"`);
  // Primer escalón con precio (el escalón 0 puede ser la capa gratuita).
  const rate = expr.tieredRates.find((r) => r.startUsageAmount === 0) ?? expr.tieredRates[0];
  const price = Number(rate.unitPrice.units ?? 0) + (rate.unitPrice.nanos ?? 0) / 1e9;
  return { unit_price: price, unit, ref: `${sel.service}: ${hits[0].description} (${expr.usageUnit})` };
}

// ---------------------------------------------------------------------------

async function resolve(m: PriceMeter): Promise<PriceEntry> {
  const api = m.provider === 'gcp' && !gcpKey ? undefined : m[m.provider];
  if (api) {
    const r = await (m.provider === 'azure' ? resolveAzure(m) : m.provider === 'aws' ? resolveAws(m) : resolveGcp(m));
    if (r.unit !== m.unit) throw new ResolveError(`la API devuelve ${r.unit} y pricing.yaml declara ${m.unit} (${r.ref})`);
    return { unit_price: round(r.unit_price), unit: r.unit, source: 'api', as_of: today, ref: r.ref };
  }
  if (m.manual) return { unit_price: m.manual.unit_price, unit: m.unit, source: 'manual', as_of: m.manual.verified_at, ref: m.manual.source };
  throw new ResolveError('sin API disponible ni precio manual');
}

const round = (n: number) => Math.round(n * 1e6) / 1e6;

const out: Record<string, PriceEntry> = {};
const failures: string[] = [];
for (const m of pricing.meters) {
  if (!only.includes(m.provider)) {
    if (previous?.prices[m.id]) out[m.id] = previous.prices[m.id];
    continue;
  }
  try {
    out[m.id] = await resolve(m);
    const e = out[m.id];
    console.log(`✓ ${m.id.padEnd(34)} ${String(e.unit_price).padStart(10)} USD/${e.unit.padEnd(8)} [${e.source}] ${e.ref}`);
  } catch (e) {
    failures.push(m.id);
    console.error(`✗ ${m.id}: ${(e as Error).message}`);
    if (previous?.prices[m.id]) out[m.id] = previous.prices[m.id];
  }
}
// --list "Servicio A|Servicio B": meters de esos servicios en la región del patrón y en las no regionales.
if (list && only.includes('azure')) {
  const regions = new Set([pricing.regions.azure, '', 'Global', 'Zone 1', 'US Zone 1']);
  for (const svc of list.split('|')) {
    try {
      const items = (await azureItems(svc, null)).filter((i) => regions.has(i.armRegionName));
      const rows = new Set(items.map((i) => `  [${i.armRegionName || '-'}] ${i.productName} | ${i.skuName} | ${i.meterName} | ${i.unitOfMeasure} | ${i.retailPrice}`));
      console.log(`\nMeters de "${svc}" (${items.length}):\n${[...rows].sort().slice(0, 400).join('\n')}`);
    } catch (e) {
      console.log(`\n--list "${svc}": ${(e as Error).message}`);
    }
  }
}
// En CI el log es la única salida: el JSON resuelto queda ahí para auditar (y copiar si hace falta).
if (check) console.log(`\nRESOLVED ${JSON.stringify(out)}`);
if (!gcpKey && only.includes('gcp')) console.log('ℹ sin GCP_BILLING_API_KEY: GCP usa los precios manuales de pricing.yaml');

if (failures.length) {
  console.error(`\n${failures.length} meter(s) sin resolver: ${failures.join(', ')}`);
  process.exit(1);
}
if (check) process.exit(0);

// Sin cambios de precio y con menos de 4 semanas: no reescribir (evita PRs semanales que solo cambian la fecha).
const changed =
  !previous ||
  Object.keys(out).length !== Object.keys(previous.prices).length ||
  Object.entries(out).some(([id, e]) => previous.prices[id]?.unit_price !== e.unit_price || previous.prices[id]?.unit !== e.unit || previous.prices[id]?.source !== e.source);
const ageDays = previous ? (Date.now() - Date.parse(previous.generated_at)) / 86_400_000 : Infinity;
if (!changed && ageDays < 28) {
  console.log('Sin cambios de precio: prices.json queda igual.');
  process.exit(0);
}
const file: Prices = { generated_at: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'), currency: 'USD', prices: Object.fromEntries(Object.entries(out).sort(([a], [b]) => a.localeCompare(b))) };
writeFileSync(pricesFile, `${JSON.stringify(file, null, 2)}\n`);
console.log(`prices.json actualizado (${Object.keys(out).length} precios).`);
