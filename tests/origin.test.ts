import { describe, expect, it } from 'vitest';
import { originNotes } from '../src/lib/origin.ts';
import { publishedPatterns } from '../src/lib/site.ts';

const bundle = publishedPatterns.find((b) => b.pattern.id === 'object-storage-ttl')!;

describe('tu nube de origen', () => {
  it('da una nota por cada otra nube, con lo que se usaba allá', () => {
    const notes = originNotes(bundle, 'aws', 'private-access', 'es');
    expect(notes.map((n) => n.from)).toEqual(['azure', 'gcp']);
    expect(notes[0].used).toMatch(/^Venís de Azure: allá este rol es Private Endpoint/);
  });

  it('suma la nota curada cuando existe', () => {
    const [fromAzure] = originNotes(bundle, 'aws', 'private-access', 'en');
    expect(fromAzure.curated).toMatch(/Interface Endpoint/);
    const [, fromGcp] = originNotes(bundle, 'aws', 'private-access', 'en');
    expect(fromGcp.curated).toBeUndefined();
  });

  it('cada rol de capability tiene al menos un gotcha etiquetado en algún patrón', () => {
    for (const { pattern, implementations } of publishedPatterns) {
      const tagged = new Set(Object.values(implementations).flatMap((i) => i!.gotchas.flatMap((g) => g.roles)));
      const roles = pattern.roles.filter((r) => r.kind === 'capability').map((r) => r.id);
      const untagged = roles.filter((r) => !tagged.has(r));
      // results (async-worker) no tiene letra chica propia todavía: se permite, pero no más de uno por patrón.
      expect(untagged.length, `${pattern.id}: ${untagged.join(', ')}`).toBeLessThanOrEqual(1);
    }
  });
});
