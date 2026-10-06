import { describe, expect, it } from 'vitest';
import { addDays, dailyIndex, demote, isDue, mastered, MAX_BOX, promote, type LeitnerState } from '../src/lib/leitner.ts';

describe('Leitner', () => {
  const today = '2026-10-06';

  it('una tarjeta nueva toca hoy; al saberla sube de caja y se aleja', () => {
    let s: LeitnerState = {};
    expect(isDue(s, 'a', today)).toBe(true);
    s = promote(s, 'a', today);
    expect(s.a).toEqual({ box: 1, due: '2026-10-07' });
    expect(isDue(s, 'a', today)).toBe(false);
    s = promote(s, 'a', '2026-10-07');
    expect(s.a).toEqual({ box: 2, due: '2026-10-09' });
  });

  it('no pasa de la última caja y repasar la devuelve a la primera para hoy', () => {
    let s: LeitnerState = {};
    for (let k = 0; k < 10; k++) s = promote(s, 'a', today);
    expect(s.a.box).toBe(MAX_BOX);
    expect(mastered(s, ['a', 'b'])).toBe(1);
    s = demote(s, 'a', today);
    expect(s.a).toEqual({ box: 1, due: today });
    expect(isDue(s, 'a', today)).toBe(true);
  });

  it('suma días cruzando meses y años', () => {
    expect(addDays('2026-12-30', 4)).toBe('2027-01-03');
    expect(addDays('2026-02-27', 2)).toBe('2026-03-01');
  });

  it('el gotcha del día es estable por fecha y está en rango', () => {
    expect(dailyIndex(today, 74)).toBe(dailyIndex(today, 74));
    const days = Array.from({ length: 30 }, (_, k) => dailyIndex(addDays(today, k), 74));
    expect(days.every((d) => d >= 0 && d < 74)).toBe(true);
    expect(new Set(days).size).toBeGreaterThan(15);
  });
});
