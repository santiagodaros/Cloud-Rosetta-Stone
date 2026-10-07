/**
 * Valida cada recurso (y bloque) de content/terraform-map.yaml contra el schema
 * real de los providers: `terraform providers schema -json` de un módulo vacío
 * con las mismas versiones. Uso: pnpm tf:map-check <schema.json>
 */
import { readFileSync } from 'node:fs';
import { loadContentOrThrow } from '../src/lib/content.ts';
import { PROVIDERS } from '../src/lib/schema.ts';
import { splitRef } from '../src/lib/terraform-map.ts';

type Block = { block_types?: Record<string, { block: Block }> };
type Schema = { provider_schemas: Record<string, { resource_schemas: Record<string, { block: Block }> }> };

const file = process.argv[2];
if (!file) {
  console.error('uso: pnpm tf:map-check <schema.json>');
  process.exit(2);
}
const schema = JSON.parse(readFileSync(file, 'utf8')) as Schema;
const resources = new Map<string, { block: Block }>();
for (const [name, p] of Object.entries(schema.provider_schemas)) {
  if (!/hashicorp\/(azurerm|aws|google)$/.test(name)) continue;
  for (const [r, s] of Object.entries(p.resource_schemas)) resources.set(r, s);
}

const { terraformMap } = loadContentOrThrow();
if (!terraformMap) {
  console.error('content/terraform-map.yaml no existe');
  process.exit(1);
}
const errors: string[] = [];
let checked = 0;
for (const e of terraformMap.entries) {
  for (const p of PROVIDERS) {
    for (const ref of e.resources[p]) {
      const { resource, block } = splitRef(ref);
      const r = resources.get(resource);
      checked++;
      if (!r) errors.push(`${e.id}: ${resource} no existe en el provider pinneado`);
      else if (block && !r.block.block_types?.[block]) errors.push(`${e.id}: ${resource} no tiene el bloque "${block}"`);
    }
  }
}
for (const err of errors) console.log(process.env.GITHUB_ACTIONS ? `::error file=content/terraform-map.yaml::${err}` : `✖ ${err}`);
console.log(`${checked} referencias, ${errors.length} error(es)`);
process.exit(errors.length ? 1 : 0);
