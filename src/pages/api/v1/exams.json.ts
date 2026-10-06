import type { APIRoute } from 'astro';
import { envelope, examStatus, gotchaKey, jsonResponse } from '../../../lib/dataset.ts';
import { gotchasForExam, site } from '../../../lib/site.ts';

/** Dataset abierto: catálogo de exámenes con su estado y los gotchas que los referencian. */
export const GET: APIRoute = () =>
  jsonResponse(
    envelope({
      exams: site.exams.map((e) => ({
        ...e,
        status: examStatus(e),
        gotchas: gotchasForExam(e.code).map((g) => gotchaKey(g.pattern.id, g.provider, g.gotcha.id)),
      })),
    }),
  );
