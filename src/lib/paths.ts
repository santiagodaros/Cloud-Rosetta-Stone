import type { Locale, Provider } from './schema.ts';

const base = import.meta.env.BASE_URL.replace(/\/$/, '');

/** Path absoluto respetando `base` (por si el sitio se sirve bajo un subpath). */
export const href = (path: string) => `${base}/${path.replace(/^\//, '')}`;

export const homeHref = (lang: Locale) => href(`${lang}/`);
export const capabilitiesHref = (lang: Locale) => href(`${lang}/capabilities/`);
export const conceptsHref = (lang: Locale) => href(`${lang}/concepts/`);
export const terraformMapHref = (lang: Locale) => href(`${lang}/terraform/`);
export const patternHref = (lang: Locale, slug: string, view?: string) =>
  href(`${lang}/patterns/${slug}/${view ? `${view}/` : ''}`);

export const examsHref = (lang: Locale, code?: string) => href(`${lang}/exams/${code ? `${code.toLowerCase()}/` : ''}`);
export const practiceHref = (lang: Locale, exam?: string) => href(`${lang}/practice/${exam ? `?exam=${exam}` : ''}`);

export const pairView = (a: Provider, b: Provider) => `${a}-vs-${b}`;
export const migrateHref = (lang: Locale, q?: { from?: Provider; to?: Provider; p?: string }) =>
  href(`${lang}/migrate/${q ? `?${new URLSearchParams(Object.entries(q).filter(([, v]) => v) as [string, string][])}` : ''}`);
export const adrHref = (lang: Locale, q?: { p?: string; cloud?: Provider }) =>
  href(`${lang}/adr/${q ? `?${new URLSearchParams(Object.entries(q).filter(([, v]) => v) as [string, string][])}` : ''}`);
export const decideHref = (lang: Locale, id?: string) => href(`${lang}/decide/${id ? `${id}/` : ''}`);
export const embedGotchaHref = (lang: Locale, pattern: string, provider: Provider, id: string) => href(`${lang}/embed/gotcha/${pattern}/${provider}/${id}/`);
export const embedCompareHref = (lang: Locale, pattern: string, view: string) => href(`${lang}/embed/compare/${pattern}/${view}/`);
