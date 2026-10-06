import type { APIRoute } from 'astro';
import { publishedPatterns } from '../../../lib/site.ts';

/** Dataset abierto: patrones publicados con implementaciones y gotchas (sin el HCL). */
export const GET: APIRoute = () =>
  new Response(
    JSON.stringify(
      {
        schema_version: 1,
        license: 'CC-BY-SA-4.0',
        patterns: publishedPatterns.map(({ pattern, implementations, terraform }) => ({
          ...pattern,
          implementations,
          terraform: Object.fromEntries(
            Object.entries(terraform).map(([p, tf]) => [p, { providers: tf!.providers, files: tf!.files.map((f) => f.name) }]),
          ),
        })),
      },
      null,
      2,
    ),
    { headers: { 'Content-Type': 'application/json; charset=utf-8' } },
  );
