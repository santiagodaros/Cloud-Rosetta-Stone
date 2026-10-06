/**
 * `pnpm launch:weekly` — genera los borradores de la serie "Gotcha de la semana"
 * (docs/launch/gotcha-de-la-semana.md) a partir del contenido publicado.
 *
 * El orden es curado (WEEKLY): los gotchas con más contraste entre nubes primero.
 * Cada borrador trae deep link al gotcha, la OG image de la comparación y las fuentes,
 * así el post siempre apunta a contenido verificado. Regeneralo después de cambiar
 * contenido o la URL del sitio (src/lib/brand.ts).
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { BRAND } from '../src/lib/brand.ts';
import { daysSince, loadContentOrThrow } from '../src/lib/content.ts';
import type { Provider } from '../src/lib/schema.ts';

const WEEKLY: [pattern: string, provider: Provider, gotcha: string][] = [
  ['object-storage-ttl', 'gcp', 'soft-delete-default-7-days'],
  ['object-storage-ttl', 'azure', 'prefix-includes-container'],
  ['async-worker', 'azure', 'peek-lock-is-at-least-once'],
  ['private-web-api', 'gcp', 'iam-sa-username-trim'],
  ['private-web-api', 'azure', 'pg-entra-app-role-needs-sql'],
  ['async-worker', 'aws', 'visibility-timeout-6x'],
  ['object-storage-ttl', 'aws', 'sourcevpce-lockout'],
  ['private-web-api', 'aws', 'fargate-private-needs-endpoints'],
  ['async-worker', 'gcp', 'dead-letter-topic-needs-subscription'],
  ['private-web-api', 'azure', 'aca-internal-needs-private-dns'],
  ['async-worker', 'azure', 'sb-private-endpoint-premium'],
  ['private-web-api', 'gcp', 'run-internal-is-not-auth'],
];

const OTHER: Record<Provider, Provider> = { azure: 'aws', aws: 'azure', gcp: 'aws' };
const NAME: Record<Provider, string> = { azure: 'Azure', aws: 'AWS', gcp: 'Google Cloud' };

const site = (process.env.SITE_URL ?? BRAND.site).replace(/\/$/, '');
const { patterns } = loadContentOrThrow();

const out: string[] = [
  '# Gotcha de la semana — borradores',
  '',
  `> Generado con \`pnpm launch:weekly\` desde el contenido publicado. Sitio: ${site}`,
  '> Antes de publicar: abrí el link, confirmá que el gotcha sigue igual y que la imagen OG se ve bien al pegar el link.',
  '',
];

WEEKLY.forEach(([patternId, provider, gotchaId], i) => {
  const bundle = patterns.find((p) => p.pattern.id === patternId);
  const gotcha = bundle?.implementations[provider]?.gotchas.find((g) => g.id === gotchaId);
  if (!bundle || !gotcha) throw new Error(`No existe ${patternId}/${provider}/${gotchaId}: actualizá WEEKLY`);

  const view = `${provider}-vs-${OTHER[provider]}`;
  const link = `${site}/es/patterns/${patternId}/${view}/#${provider}-${gotchaId}`;
  const og = `${site}/og/es/${patternId}/${view}.png`;
  const tags = ['#Multicloud', `#${NAME[provider].replace(/\s/g, '')}`, ...gotcha.exams.slice(0, 2).map((e) => `#${e.replace(/-/g, '')}`)];

  out.push(
    `## Semana ${i + 1} — ${NAME[provider]}: ${gotcha.title.es}`,
    '',
    `- Patrón: **${bundle.pattern.title.es}** · severidad \`${gotcha.severity}\` · verificado hace ${daysSince(gotcha.verified_at)} días`,
    `- Link (primer comentario): ${link}`,
    `- Imagen: ${og}`,
    '',
    '```text',
    `Letra chica de ${NAME[provider]} #${i + 1}: ${gotcha.title.es}`,
    '',
    gotcha.body.es,
    '',
    `¿Y en las otras nubes? Está comparado lado a lado, con la fuente oficial y el Terraform que lo resuelve. Link en el primer comentario.`,
    '',
    tags.join(' '),
    '```',
    '',
    'Fuentes:',
    ...gotcha.sources.map((s) => `- ${s}`),
    '',
  );
});

mkdirSync('docs/launch', { recursive: true });
writeFileSync('docs/launch/gotcha-de-la-semana.md', out.join('\n'));
console.log(`docs/launch/gotcha-de-la-semana.md: ${WEEKLY.length} semanas`);
