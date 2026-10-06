/**
 * Carga del dataset publicado. Por defecto lee el sitio público; con
 * LETRA_CHICA_DATA se puede apuntar a otra URL base o a una carpeta local
 * (por ejemplo `dist/api/v1` después de `pnpm build`).
 */
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { checkSchema, type Dataset } from './core.ts';

export const DEFAULT_DATA = 'https://santiagodaros.github.io/Cloud-Rosetta-Stone/api/v1/';
const TTL_MS = 60 * 60 * 1000;
const FILES = ['gotchas', 'patterns', 'capabilities', 'exams'] as const;

let cache: { at: number; ds: Dataset } | undefined;

async function readJson(base: string, name: string): Promise<Record<string, unknown>> {
  if (/^https?:\/\//.test(base)) {
    const url = new URL(`${name}.json`, base.endsWith('/') ? base : `${base}/`);
    const res = await fetch(url, { headers: { 'User-Agent': 'letra-chica-mcp' } });
    if (!res.ok) throw new Error(`GET ${url} → ${res.status}`);
    return (await res.json()) as Record<string, unknown>;
  }
  return JSON.parse(await readFile(join(base, `${name}.json`), 'utf8')) as Record<string, unknown>;
}

export async function loadDataset(base = process.env.LETRA_CHICA_DATA ?? DEFAULT_DATA): Promise<Dataset> {
  if (cache && Date.now() - cache.at < TTL_MS) return cache.ds;
  const [gotchas, patterns, capabilities, exams] = await Promise.all(FILES.map((f) => readJson(base, f)));
  for (const part of [gotchas, patterns, capabilities, exams]) checkSchema(part as { schema_version?: number });
  // Endpoints más nuevos: si el sitio todavía no los publica, las herramientas que los usan devuelven vacío.
  const optional = (name: string) => readJson(base, name).catch(() => ({}) as Record<string, unknown>);
  const [concepts, terraformMap] = await Promise.all([optional('concepts'), optional('terraform-map')]);
  const ds: Dataset = {
    schema_version: gotchas.schema_version as number,
    generated_at: gotchas.generated_at as string,
    attribution: gotchas.attribution as string,
    gotchas: gotchas.gotchas as Dataset['gotchas'],
    patterns: patterns.patterns as Dataset['patterns'],
    capabilities: capabilities.capabilities as Dataset['capabilities'],
    exams: exams.exams as Dataset['exams'],
    concepts: (concepts.concepts as Dataset['concepts']) ?? [],
    terraformMap: (terraformMap.entries as Dataset['terraformMap']) ?? [],
  };
  cache = { at: Date.now(), ds };
  return ds;
}
