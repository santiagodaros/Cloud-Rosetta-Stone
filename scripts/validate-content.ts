/**
 * `pnpm validate` — valida todo `content/` (schema + referencias cruzadas).
 * Sale con código 1 si hay errores. Los warnings no bloquean, pero se muestran.
 * En GitHub Actions emite anotaciones para que aparezcan en el diff del PR.
 */
import { loadContent } from '../src/lib/content.ts';

const { issues, patterns, capabilities } = loadContent();
const inCI = process.env.GITHUB_ACTIONS === 'true';

for (const i of issues) {
  if (inCI) {
    const msg = i.message.replace(/%/g, '%25').replace(/\r?\n/g, '%0A');
    console.log(`::${i.level} file=${i.file}::${msg}`);
  } else {
    console.log(`${i.level === 'error' ? '✖' : '⚠'} ${i.file}\n    ${i.message.replace(/\n/g, '\n    ')}`);
  }
}

const errors = issues.filter((i) => i.level === 'error').length;
const warnings = issues.length - errors;
const gotchas = patterns.reduce(
  (n, p) => n + Object.values(p.implementations).reduce((m, impl) => m + (impl?.gotchas.length ?? 0), 0),
  0,
);
console.log(
  `\n${patterns.length} patrón(es), ${capabilities.length} capabilities, ${gotchas} gotchas — ${errors} error(es), ${warnings} warning(s)`,
);
process.exit(errors > 0 ? 1 : 0);
