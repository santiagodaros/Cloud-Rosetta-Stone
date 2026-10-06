import type { APIRoute } from 'astro';
import { envelope, jsonResponse } from '../../../lib/dataset.ts';
import { publishedPatterns } from '../../../lib/site.ts';

/** Dataset abierto: patrones publicados con implementaciones y gotchas (sin el HCL). */
export const GET: APIRoute = () =>
  jsonResponse(
    envelope({
      patterns: publishedPatterns.map(({ pattern, implementations, terraform }) => ({
        ...pattern,
        implementations,
        terraform: Object.fromEntries(
          Object.entries(terraform).map(([p, tf]) => [p, { providers: tf!.providers, files: tf!.files.map((f) => f.name) }]),
        ),
      })),
    }),
  );
