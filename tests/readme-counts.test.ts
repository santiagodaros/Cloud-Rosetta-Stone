import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { loadContent } from '../src/lib/content.ts';

// El README cita cuántos patrones, gotchas y capabilities hay. Si el contenido cambia y el README no, este test
// avisa en vez de dejar que los números se desfasen (pasó con los patrones OIDC y DNS híbrido).
describe('README', () => {
  it('cita los mismos patrones publicados, gotchas y capabilities que el contenido', () => {
    const { patterns, capabilities } = loadContent();
    const published = patterns.filter(({ pattern }) => pattern.status === 'published');
    const gotchas = published.reduce((n, { implementations }) => n + Object.values(implementations).reduce((m, impl) => m + impl!.gotchas.length, 0), 0);
    const readme = readFileSync(new URL('../README.md', import.meta.url), 'utf8');
    const m = readme.match(/(\d+) patrones en las 3 nubes, (\d+) gotchas con fuente oficial, (\d+) capabilities/);
    expect(m, 'no se encontró la línea de conteos en README.md').not.toBeNull();
    expect([Number(m![1]), Number(m![2]), Number(m![3])]).toEqual([published.length, gotchas, capabilities.length]);
  });
});
