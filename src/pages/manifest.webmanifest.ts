import type { APIRoute } from 'astro';
import { BRAND } from '../lib/brand.ts';
import { href } from '../lib/paths.ts';
import { ui } from '../lib/i18n.ts';

/** Web app manifest (F4-19). Generado para respetar el `base` de GitHub Pages. */
export const GET: APIRoute = () =>
  new Response(
    JSON.stringify({
      name: BRAND.name,
      short_name: BRAND.name,
      description: ui('es').tagline,
      lang: 'es',
      start_url: href(''),
      scope: href(''),
      display: 'standalone',
      background_color: '#f5f5f7',
      theme_color: '#4338ca',
      icons: [
        { src: href('icons/192.png'), sizes: '192x192', type: 'image/png' },
        { src: href('icons/512.png'), sizes: '512x512', type: 'image/png' },
        { src: href('icons/maskable-512.png'), sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    }),
    { headers: { 'content-type': 'application/manifest+json' } },
  );
