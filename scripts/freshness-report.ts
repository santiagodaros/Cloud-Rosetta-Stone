/**
 * `pnpm freshness` — reporte de gotchas a re-verificar (verified_at viejo).
 * Escribe markdown a stdout; el workflow programado lo usa como cuerpo de un issue.
 * Sale con 0 siempre: la frescura es una tarea de mantenimiento, no un build roto.
 */
import { daysSince, loadContent, STALE_AFTER_DAYS } from '../src/lib/content.ts';

const WARN_AFTER_DAYS = STALE_AFTER_DAYS - 30;
const { patterns } = loadContent();

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
