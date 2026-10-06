/**
 * Datos del sitio cargados una sola vez por build. Si el contenido es inválido,
 * el build falla: nunca se publica algo que no pasó `pnpm validate`.
 */
import { loadContentOrThrow } from './content.ts';
import type { Exam, Gotcha, Pattern, Provider } from './schema.ts';
import { PROVIDERS } from './schema.ts';

export const site = loadContentOrThrow();

export const publishedPatterns = site.patterns.filter((p) => p.pattern.status === 'published');

/** Vistas de comparación: todos los pares ordenados + "all" (las tres nubes). */
export const VIEWS: { id: string; providers: Provider[] }[] = [
  ...PROVIDERS.flatMap((a) => PROVIDERS.filter((b) => b !== a).map((b) => ({ id: `${a}-vs-${b}`, providers: [a, b] }))),
  { id: 'all', providers: [...PROVIDERS] },
];
export const DEFAULT_VIEW = 'azure-vs-aws';

/** Todos los gotchas publicados en una lista plana (exámenes, práctica, API). */
export type GotchaEntry = { pattern: Pattern; provider: Provider; gotcha: Gotcha; anchor: string };
export const allGotchas: GotchaEntry[] = publishedPatterns.flatMap(({ pattern, implementations }) =>
  PROVIDERS.flatMap((provider) =>
    (implementations[provider]?.gotchas ?? []).map((gotcha) => ({ pattern, provider, gotcha, anchor: `${provider}-${gotcha.id}` })),
  ),
);

export const examsByCode = new Map<string, Exam>(site.exams.map((e) => [e.code, e]));
export const gotchasForExam = (code: string) => allGotchas.filter((g) => g.gotcha.exams.includes(code));
