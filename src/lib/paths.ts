import type { Locale, Provider } from './schema.ts';

const base = import.meta.env.BASE_URL.replace(/\/$/, '');

/** Path absoluto respetando `base` (GitHub Pages sirve en /<repo>/). */
export const href = (path: string) => `${base}/${path.replace(/^\//, '')}`;

export const homeHref = (lang: Locale) => href(`${lang}/`);
export const capabilitiesHref = (lang: Locale) => href(`${lang}/capabilities/`);
export const patternHref = (lang: Locale, slug: string, view?: string) =>
  href(`${lang}/patterns/${slug}/${view ? `${view}/` : ''}`);

export const pairView = (a: Provider, b: Provider) => `${a}-vs-${b}`;
