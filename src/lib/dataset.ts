/**
 * Contrato del dataset abierto (`/api/v1/*.json`, `llms.txt`).
 *
 * `schema_version` sube solo con cambios incompatibles (renombrar o quitar un
 * campo). Agregar campos no la cambia: los consumidores deben ignorar lo que no
 * conocen. Ver docs/DATASET.md.
 */
import { BRAND } from './brand.ts';
import { href, patternHref } from './paths.ts';
import type { Locale } from './schema.ts';
import { examStatus } from './content.ts';
import { allGotchas, publishedPatterns, site } from './site.ts';

export const SCHEMA_VERSION = 1;
export const LICENSE = 'CC-BY-SA-4.0';

/** Momento del build: todas las respuestas de un mismo deploy comparten la fecha. */
export const GENERATED_AT = new Date().toISOString();

export const absolute = (path: string, siteUrl: URL | undefined) => new URL(path, siteUrl ?? BRAND.site).href;

export function envelope<T extends object>(payload: T) {
  return {
    schema_version: SCHEMA_VERSION,
    generated_at: GENERATED_AT,
    license: LICENSE,
    attribution: `${BRAND.name} (${BRAND.site}), CC BY-SA 4.0`,
    ...payload,
  };
}

export const jsonResponse = (body: unknown) =>
  new Response(JSON.stringify(body, null, 2), { headers: { 'Content-Type': 'application/json; charset=utf-8' } });

/** Identificador estable de un gotcha en todo el dataset. */
export const gotchaKey = (pattern: string, provider: string, id: string) => `${pattern}/${provider}/${id}`;

/** Gotchas en una lista plana, con URL absoluta por idioma. Es lo que consume el MCP server. */
export function flatGotchas(siteUrl: URL | undefined) {
  return allGotchas.map(({ pattern, provider, gotcha: g, anchor }) => ({
    key: gotchaKey(pattern.id, provider, g.id),
    pattern: pattern.id,
    provider,
    id: g.id,
    severity: g.severity,
    title: g.title,
    body: g.body,
    sources: g.sources,
    verified_at: g.verified_at,
    verified_by: g.verified_by ?? null,
    exams: g.exams,
    roles: g.roles,
    url: Object.fromEntries(
      (['es', 'en'] as Locale[]).map((l) => [l, `${absolute(patternHref(l, pattern.id, 'all'), siteUrl)}#${anchor}`]),
    ),
  }));
}

export function datasetIndex(siteUrl: URL | undefined) {
  const api = (name: string) => absolute(href(`api/v1/${name}.json`), siteUrl);
  return {
    name: BRAND.name,
    repository: BRAND.repo,
    counts: {
      patterns: publishedPatterns.length,
      gotchas: allGotchas.length,
      capabilities: site.capabilities.length,
      exams: site.exams.length,
      concepts: site.concepts.length,
      terraform_map_entries: site.terraformMap?.entries.length ?? 0,
      price_meters: site.pricing?.meters.length ?? 0,
      decisions: site.decisions?.length ?? 0,
    },
    endpoints: {
      patterns: api('patterns'),
      gotchas: api('gotchas'),
      capabilities: api('capabilities'),
      exams: api('exams'),
      concepts: api('concepts'),
      terraform_map: api('terraform-map'),
      pricing: api('pricing'),
      decisions: api('decisions'),
      llms_txt: absolute(href('llms.txt'), siteUrl),
      llms_full_txt: absolute(href('llms-full.txt'), siteUrl),
    },
  };
}

export { examStatus };
