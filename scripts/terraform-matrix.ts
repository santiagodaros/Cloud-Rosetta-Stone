/**
 * `pnpm tf:matrix` — lista los módulos de Terraform de `content/` como matriz
 * JSON para GitHub Actions: [{ "dir": "...", "provider": "azure" }, ...].
 */
import { loadContent } from '../src/lib/content.ts';
import { relative } from 'node:path';

const { patterns } = loadContent();
const matrix = patterns.flatMap(({ terraform }) =>
  Object.entries(terraform).map(([provider, tf]) => ({ dir: relative(process.cwd(), tf!.dir), provider })),
);
console.log(JSON.stringify(matrix));
