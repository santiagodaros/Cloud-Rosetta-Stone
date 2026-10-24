/**
 * `pnpm freshness` — reporte de gotchas a re-verificar (verified_at viejo).
 * Escribe markdown a stdout; el workflow programado lo usa como cuerpo de un issue.
 * Sale con 0 siempre: la frescura es una tarea de mantenimiento, no un build roto.
 */
import { daysSince, loadContent, STALE_AFTER_DAYS } from '../src/lib/content.ts';
import { SEVERITIES } from '../src/lib/schema.ts';

const WARN_AFTER_DAYS = STALE_AFTER_DAYS - 30;
const { patterns } = loadContent();

// `pnpm freshness --review`: gotchas sin revisor externo (sin `verified_by`), los más severos primero.
// Es la cola de trabajo para quien se ofrece a revisar una nube; no reemplaza el reporte de frescura.
if (process.argv.includes('--review')) {
  const queue = patterns.flatMap(({ pattern, implementations }) =>
    Object.entries(implementations).flatMap(([provider, impl]) =>
      impl!.gotchas.filter((g) => !g.verified_by).map((g) => ({ pattern: pattern.id, provider, id: g.id, severity: g.severity, age: daysSince(g.verified_at), sources: g.sources })),
    ),
  );
  queue.sort((a, b) => SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity) || b.age - a.age);
  console.log(`${queue.length} gotchas sin revisor externo. Para revisar uno: leé las fuentes, corregí el texto si hace falta, actualizá \`verified_at\` y agregá \`verified_by: <tu usuario de GitHub>\`.\n`);
  for (const provider of ['azure', 'aws', 'gcp']) {
    const rows = queue.filter((r) => r.provider === provider);
    console.log(`## ${provider} (${rows.length})\n`);
    console.log('| Severidad | Patrón | Gotcha | Días | Fuentes |');
    console.log('|---|---|---|---|---|');
    for (const r of rows) console.log(`| ${r.severity} | ${r.pattern} | \`${r.id}\` | ${r.age} | ${r.sources.map((s, i) => `[${i + 1}](${s})`).join(' ')} |`);
    console.log('');
  }
  process.exit(0);
}

type Row = { pattern: string; provider: string; id: string; age: number; sources: string[] };
const rows: Row[] = [];
for (const { pattern, implementations } of patterns) {
  for (const [provider, impl] of Object.entries(implementations)) {
    for (const g of impl!.gotchas) {
      const age = daysSince(g.verified_at);
      if (age >= WARN_AFTER_DAYS) rows.push({ pattern: pattern.id, provider, id: g.id, age, sources: g.sources });
    }
  }
}
rows.sort((a, b) => b.age - a.age);

if (rows.length === 0) {
  console.log(`Todos los gotchas fueron verificados hace menos de ${WARN_AFTER_DAYS} días. ✅`);
} else {
  console.log(`Gotchas verificados hace ${WARN_AFTER_DAYS}+ días (vencen a los ${STALE_AFTER_DAYS}).\n`);
  console.log('Para cada uno: revisá las fuentes, corregí el texto si cambió algo y actualizá `verified_at`.\n');
  console.log('| Estado | Patrón | Nube | Gotcha | Días | Fuentes |');
  console.log('|---|---|---|---|---|---|');
  for (const r of rows) {
    const state = r.age > STALE_AFTER_DAYS ? '🔴 vencido' : '🟡 por vencer';
    const links = r.sources.map((s, i) => `[${i + 1}](${s})`).join(' ');
    console.log(`| ${state} | ${r.pattern} | ${r.provider} | \`${r.id}\` | ${r.age} | ${links} |`);
  }
}
