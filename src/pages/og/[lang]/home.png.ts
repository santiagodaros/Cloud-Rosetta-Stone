import type { APIRoute } from 'astro';
import { LOCALES, ui, type Locale } from '../../../lib/i18n.ts';
import { renderOgPng } from '../../../lib/og.ts';
import { PROVIDERS } from '../../../lib/schema.ts';
import { publishedPatterns } from '../../../lib/site.ts';

export function getStaticPaths() {
  return LOCALES.map((lang) => ({ params: { lang } }));
}

export const GET: APIRoute = async ({ params }) => {
  const s = ui(params.lang as Locale);
  const gotchas = publishedPatterns.reduce(
    (n, b) => n + PROVIDERS.reduce((m, p) => m + (b.implementations[p]?.gotchas.length ?? 0), 0),
    0,
  );
  const png = await renderOgPng({
    title: s.tagline,
    kicker: s.patternCount(publishedPatterns.length),
    providers: [...PROVIDERS],
    footer: s.ogFooter(gotchas),
  });
  return new Response(new Uint8Array(png), { headers: { 'Content-Type': 'image/png' } });
};
