import type { APIRoute, GetStaticPaths } from 'astro';
import { LOCALES, t, ui, type Locale } from '../../../../lib/i18n.ts';
import { renderOgPng } from '../../../../lib/og.ts';
import { publishedPatterns, VIEWS } from '../../../../lib/site.ts';

export const getStaticPaths = (() =>
  LOCALES.flatMap((lang) =>
    publishedPatterns.flatMap((bundle) =>
      VIEWS.map((view) => ({ params: { lang, slug: bundle.pattern.id, view: view.id }, props: { bundle, view } })),
    ),
  )) satisfies GetStaticPaths;

export const GET: APIRoute = async ({ params, props }) => {
  const lang = params.lang as Locale;
  const { bundle, view } = props as ReturnType<typeof getStaticPaths>[number]['props'];
  const s = ui(lang);
  const gotchas = view.providers.reduce((n, p) => n + (bundle.implementations[p]?.gotchas.length ?? 0), 0);
  const png = await renderOgPng({
    title: t(bundle.pattern.title, lang),
    kicker: s.ogKicker,
    providers: view.providers,
    footer: s.ogFooter(gotchas),
  });
  return new Response(new Uint8Array(png), { headers: { 'Content-Type': 'image/png' } });
};
