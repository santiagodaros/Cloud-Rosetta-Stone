import type { APIRoute } from 'astro';
import { examStatus } from '../../../lib/content.ts';
import { gotchasForExam, site } from '../../../lib/site.ts';

/** Dataset abierto: catálogo de exámenes con su estado y los gotchas que los referencian. */
export const GET: APIRoute = () =>
  new Response(
    JSON.stringify(
      {
        schema_version: 1,
        license: 'CC-BY-SA-4.0',
        exams: site.exams.map((e) => ({
          ...e,
          status: examStatus(e),
          gotchas: gotchasForExam(e.code).map((g) => ({ pattern: g.pattern.id, provider: g.provider, id: g.gotcha.id })),
        })),
      },
      null,
      2,
    ),
    { headers: { 'Content-Type': 'application/json; charset=utf-8' } },
  );
