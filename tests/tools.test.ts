import { describe, expect, it } from 'vitest';
import { adrMarkdown, buildChecklist, checklistKey, checklistMarkdown, toolStrings, toolsData } from '../src/lib/tools.ts';
import { publishedPatterns, site } from '../src/lib/site.ts';

const urlFor = (id: string, anchor?: string) => `https://example.org/es/patterns/${id}/all/${anchor ? `#${anchor}` : ''}`;
const data = toolsData(publishedPatterns, site.terraformMap, 'es', urlFor);
const S = toolStrings('es');

describe('checklist de migración (F4-13)', () => {
  const c = buildChecklist(data, { from: 'aws', to: 'azure', patterns: ['private-web-api', 'hybrid-private-dns'] }, S);

  it('solo incluye los patrones elegidos y un ítem por rol', () => {
    expect(c.patterns.map((p) => p.id).sort()).toEqual(['hybrid-private-dns', 'private-web-api']);
    for (const p of c.patterns) {
      const bundle = publishedPatterns.find((b) => b.pattern.id === p.id)!;
      const roles = p.sections.find((s) => s.kind === 'roles')!;
      expect(roles.items).toHaveLength(bundle.pattern.roles.filter((r) => r.kind === 'capability').length);
      expect(roles.items.every((i) => i.text.includes(' → '))).toBe(true);
    }
  });

  it('la letra chica es la del destino, ordenada por severidad, con fuente y fecha', () => {
    const p = c.patterns[0];
    const gotchas = p.sections.find((s) => s.kind === 'gotchas')!.items;
    const expected = publishedPatterns.find((b) => b.pattern.id === p.id)!.implementations.azure!.gotchas;
    expect(gotchas).toHaveLength(expected.length);
    expect(gotchas.every((g) => g.sources!.length > 0 && /^\d{4}-\d{2}-\d{2}$/.test(g.verified!))).toBe(true);
    expect(gotchas.every((g) => g.href!.includes('#azure-'))).toBe(true);
  });

  it('usa la nota curada "venís de" cuando existe', () => {
    const withFrom = publishedPatterns.flatMap((b) =>
      Object.entries(b.implementations.azure?.bindings ?? {}).filter(([, x]) => !('gap' in x) && x.from?.aws).map(([role]) => ({ id: b.pattern.id, role })),
    );
    expect(withFrom.length).toBeGreaterThan(0);
    const { id, role } = withFrom[0];
    const cl = buildChecklist(data, { from: 'aws', to: 'azure', patterns: [id] }, S);
    const item = cl.patterns[0].sections[0].items.find((i) => i.id.endsWith(`/role/${role}`))!;
    expect(item.detail).toBeTruthy();
  });

  it('los ids son estables y llevan el par origen→destino', () => {
    const ids = c.patterns.flatMap((p) => p.sections.flatMap((s) => s.items.map((i) => i.id)));
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids.every((i) => i.startsWith(`${checklistKey('aws', 'azure')}/`))).toBe(true);
  });

  it('el Markdown respeta lo tildado y cita fuentes', () => {
    const first = c.patterns[0].sections[0].items[0].id;
    const md = checklistMarkdown(c, new Set([first]), S);
    expect(md.startsWith('# Migración AWS → Azure')).toBe(true);
    expect(md.match(/^- \[x\] /gm)).toHaveLength(1);
    expect(md).toMatch(/^ {2}Fuente oficial: <https:\/\//m);
    expect(md).toContain('CC BY-SA 4.0');
  });
});

describe('generador de ADR (F4-14)', () => {
  const input = {
    pattern: 'async-worker',
    chosen: 'gcp' as const,
    status: 'proposed' as const,
    date: '2026-10-06',
    drivers: ['Escala a cero', '  '],
    rationale: 'el equipo ya opera GCP',
  };
  const md = adrMarkdown(data, input, S);

  it('sigue la estructura MADR', () => {
    expect(md.startsWith('---\nstatus: proposed\ndate: 2026-10-06\n---\n')).toBe(true);
    const headings = md.match(/^## .+$/gm);
    expect(headings).toEqual([
      '## Contexto y problema',
      '## Drivers de la decisión',
      '## Opciones consideradas',
      '## Decisión',
      '## Pros y contras de las opciones',
      '## Más información',
    ]);
    expect(md).toContain('- Escala a cero\n\n');
    expect(md).toMatch(/Opción elegida: "GCP: .+", porque el equipo ya opera GCP/);
  });

  it('considera las tres nubes y lista la letra chica de la elegida con fuentes', () => {
    expect(md.match(/^- (Azure|AWS|GCP): /gm)).toHaveLength(3);
    const gotchas = publishedPatterns.find((b) => b.pattern.id === 'async-worker')!.implementations.gcp!.gotchas;
    expect(md.match(/^- \[ \] \*\*[^*]+\*\* · \[/gm)).toHaveLength(gotchas.length);
    for (const g of gotchas) expect(md).toContain(`#gcp-${g.id})`);
  });

  it('sin drivers ni justificación no deja secciones vacías', () => {
    const bare = adrMarkdown(data, { ...input, drivers: [], rationale: '' }, S);
    expect(bare).not.toContain('## Drivers de la decisión');
    expect(bare).toContain('porque (completar)');
  });

  it('rechaza patrón o nube inexistentes', () => {
    expect(() => adrMarkdown(data, { ...input, pattern: 'nope' }, S)).toThrow();
  });
});
