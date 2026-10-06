import { describe, expect, it } from 'vitest';
import { envelope, flatGotchas, SCHEMA_VERSION } from '../src/lib/dataset.ts';
import { llmsFullTxt, llmsTxt } from '../src/lib/llms.ts';
import { allGotchas } from '../src/lib/site.ts';

const site = new URL('https://example.org/');

describe('dataset', () => {
  it('cada respuesta lleva versión, fecha, licencia y atribución', () => {
    const e = envelope({ x: 1 });
    expect(e.schema_version).toBe(SCHEMA_VERSION);
    expect(Date.parse(e.generated_at)).not.toBeNaN();
    expect(e.license).toBe('CC-BY-SA-4.0');
    expect(e.attribution).toMatch(/CC BY-SA/);
  });

  it('las claves de gotcha son únicas y los links apuntan al ancla del gotcha', () => {
    const flat = flatGotchas(site);
    expect(new Set(flat.map((g) => g.key)).size).toBe(flat.length);
    for (const g of flat) {
      expect(g.url.en).toBe(`https://example.org/en/patterns/${g.pattern}/all/#${g.provider}-${g.id}`);
      expect(g.sources.length).toBeGreaterThan(0);
    }
  });
});

describe('llms.txt', () => {
  it('sigue el formato llmstxt.org: H1, resumen en blockquote y secciones con links', () => {
    const txt = llmsTxt(site);
    expect(txt.split('\n')[0]).toMatch(/^# /);
    expect(txt).toMatch(/\n> .+/);
    expect(txt).toMatch(/\n## Patterns\n\n- \[.+\]\(https:\/\/example\.org\/en\/patterns\//);
  });

  it('llms-full.txt incluye cada gotcha con su fuente y su fecha', () => {
    const full = llmsFullTxt(site);
    for (const { pattern, provider, gotcha } of allGotchas) {
      expect(full).toContain(`- key: ${pattern.id}/${provider}/${gotcha.id}`);
    }
    expect(full.match(/^- sources: https:\/\//gm)?.length).toBe(allGotchas.length);
  });
});
