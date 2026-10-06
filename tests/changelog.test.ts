import { describe, expect, it } from 'vitest';
import { computeChangelog, wordDiff } from '../src/lib/changelog.ts';
import { allGotchas } from '../src/lib/site.ts';

describe('changelog', () => {
  it('cada gotcha publicado aparece como nuevo en algún commit (con historial completo)', () => {
    const events = computeChangelog();
    if (events.length === 0) return; // checkout superficial: no hay historial que comparar
    const added = new Set(events.filter((e) => e.kind === 'added').map((e) => `${e.pattern}/${e.provider}/${e.id}`));
    for (const { pattern, provider, gotcha } of allGotchas) expect(added).toContain(`${pattern.id}/${provider}/${gotcha.id}`);
    for (const e of events) expect(e.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});

describe('wordDiff', () => {
  it('marca solo las palabras que cambiaron', () => {
    const parts = wordDiff('la cola expira a los 7 días', 'la cola expira a los 14 días');
    expect(parts.filter((p) => p.op === 'del').map((p) => p.text.trim())).toEqual(['7']);
    expect(parts.filter((p) => p.op === 'ins').map((p) => p.text.trim())).toEqual(['14']);
    expect(parts.map((p) => (p.op === 'del' ? '' : p.text)).join('')).toBe('la cola expira a los 14 días');
  });
});
