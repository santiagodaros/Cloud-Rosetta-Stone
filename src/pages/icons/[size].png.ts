import type { APIRoute } from 'astro';
import { Resvg } from '@resvg/resvg-js';

/**
 * Íconos de la PWA (F4-19), derivados de public/favicon.svg. `maskable` deja el logo dentro de la
 * zona segura (80 % central) sobre fondo lleno, para que Android pueda recortarlo en círculo.
 */
const SIZES = { '192': { size: 192, maskable: false }, '512': { size: 512, maskable: false }, 'maskable-512': { size: 512, maskable: true } } as const;

export function getStaticPaths() {
  return Object.keys(SIZES).map((size) => ({ params: { size } }));
}

const glyph =
  '<path d="M7 10h7M7 16h7M7 22h7M18 10h7M18 16h7M18 22h7" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><path d="M14 10l4 6-4 6" stroke="#c7d2fe" stroke-width="1.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>';

export const GET: APIRoute = ({ params }) => {
  const { size, maskable } = SIZES[params.size as keyof typeof SIZES];
  const svg = maskable
    ? `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" fill="#4338ca"/><g transform="translate(4.8 4.8) scale(0.7)">${glyph}</g></svg>`
    : `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="7" fill="#4338ca"/>${glyph}</svg>`;
  const png = new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render().asPng();
  return new Response(new Uint8Array(png), { headers: { 'content-type': 'image/png' } });
};
