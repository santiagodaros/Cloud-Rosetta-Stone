import { describe, expect, it } from 'vitest';
import { renderOgPng } from '../src/lib/og.ts';

describe('renderOgPng', () => {
  it('genera un PNG de 1200×630', async () => {
    const png = await renderOgPng({ title: 'Patrón de prueba', kicker: 'Test', providers: ['azure', 'aws'], footer: '3 gotchas' });
    expect(png.subarray(0, 8)).toEqual(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    expect(png.readUInt32BE(16)).toBe(1200);
    expect(png.readUInt32BE(20)).toBe(630);
    // La primera llamada carga fuentes y WASM en frío: con la suite en paralelo (el test del changelog corre `git log`)
    // supera los 5 s por defecto. Aislado tarda menos de 1 s.
  }, 30_000);
});
