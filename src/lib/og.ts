/**
 * Imágenes Open Graph (1200×630) generadas en build time con satori → PNG.
 * Cada comparación tiene la suya: es lo que aparece al pegar el link en LinkedIn o Slack.
 */
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import satori from 'satori';
import { Resvg } from '@resvg/resvg-js';
import type { Provider } from './schema.ts';

const require = createRequire(import.meta.url);
const font = (weight: 400 | 700) =>
  readFileSync(require.resolve(`@fontsource/inter/files/inter-latin-${weight}-normal.woff`));

const FONTS = [
  { name: 'Inter', data: font(400), weight: 400 as const, style: 'normal' as const },
  { name: 'Inter', data: font(700), weight: 700 as const, style: 'normal' as const },
];

// Colores fijos (la imagen no depende del tema del visitante).
const C = { bg: '#0d1117', text: '#e6edf3', muted: '#9198a1', accent: '#a5b4fc', azure: '#4aa3f0', aws: '#ff9f43', gcp: '#6dd58c' };
const SHORT: Record<Provider, string> = { azure: 'Azure', aws: 'AWS', gcp: 'GCP' };

type Node = { type: string; props: { style?: Record<string, unknown>; children?: unknown } };
const h = (type: string, style: Record<string, unknown>, children?: unknown): Node => ({ type, props: { style, children } });

export type OgInput = {
  title: string;
  kicker: string;
  providers: Provider[];
  footer: string;
};

export async function renderOgPng({ title, kicker, providers, footer }: OgInput): Promise<Buffer> {
  const chips = providers.flatMap((p, i) => [
    ...(i > 0 ? [h('div', { color: C.muted, fontSize: 30, margin: '0 14px' }, 'vs')] : []),
    h('div', { color: C[p], border: `3px solid ${C[p]}`, borderRadius: 999, padding: '6px 26px', fontSize: 30, fontWeight: 700 }, SHORT[p]),
  ]);

  const tree = h(
    'div',
    { width: 1200, height: 630, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', background: C.bg, padding: '64px 72px', fontFamily: 'Inter' },
    [
      h('div', { display: 'flex', flexDirection: 'column' }, [
        h('div', { color: C.accent, fontSize: 26, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 22 }, kicker),
        h('div', { color: C.text, fontSize: title.length > 60 ? 54 : 64, fontWeight: 700, lineHeight: 1.12 }, title),
      ]),
      h('div', { display: 'flex', alignItems: 'center' }, chips),
      h('div', { display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: C.muted, fontSize: 24 }, [
        h('div', { display: 'flex', color: C.text, fontWeight: 700 }, 'Cloud Rosetta Stone'),
        h('div', { display: 'flex' }, footer),
      ]),
    ],
  );

  const svg = await satori(tree as Parameters<typeof satori>[0], { width: 1200, height: 630, fonts: FONTS });
  return new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } }).render().asPng();
}
