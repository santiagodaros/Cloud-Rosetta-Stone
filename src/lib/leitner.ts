/**
 * Repetición espaciada con cajas de Leitner (F4-17), sin cuentas: el progreso
 * vive en localStorage del navegador. Pura para poder testearla.
 */

/** Días hasta el próximo repaso según la caja (1 = todos los días, 5 = cada 16 días). */
export const INTERVAL_DAYS = [0, 1, 2, 4, 8, 16] as const;
export const MAX_BOX = 5;

export type CardState = { box: number; due: string };
export type LeitnerState = Record<string, CardState>;

/** Fecha local del usuario en YYYY-MM-DD (el día de repaso es el del usuario, no UTC). */
export function localDay(d = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function addDays(day: string, n: number): string {
  const [y, m, d] = day.split('-').map(Number);
  return localDay(new Date(y, m - 1, d + n));
}

/** Una tarjeta nunca vista también "toca hoy". */
export const isDue = (state: LeitnerState, id: string, today: string) => !state[id] || state[id].due <= today;

export function promote(state: LeitnerState, id: string, today: string): LeitnerState {
  const box = Math.min(MAX_BOX, (state[id]?.box ?? 0) + 1);
  return { ...state, [id]: { box, due: addDays(today, INTERVAL_DAYS[box]) } };
}

export function demote(state: LeitnerState, id: string, today: string): LeitnerState {
  return { ...state, [id]: { box: 1, due: today } };
}

export const mastered = (state: LeitnerState, ids: string[]) => ids.filter((id) => state[id]?.box === MAX_BOX).length;

/** Índice determinístico por día: todos ven el mismo "gotcha del día". */
export function dailyIndex(day: string, n: number): number {
  let h = 2166136261;
  for (const ch of day) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return (h >>> 0) % n;
}

/** Lectura y escritura tolerantes: modo privado o storage bloqueado no rompen la página. */
export function loadState(key: string): LeitnerState {
  try {
    const raw = localStorage.getItem(key);
    const parsed = raw ? (JSON.parse(raw) as unknown) : {};
    return parsed && typeof parsed === 'object' ? (parsed as LeitnerState) : {};
  } catch {
    return {};
  }
}

export function saveState(key: string, state: LeitnerState): void {
  try {
    localStorage.setItem(key, JSON.stringify(state));
  } catch {
    /* sin storage: el progreso dura lo que dura la pestaña */
  }
}
