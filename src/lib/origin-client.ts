/** Lado cliente de "Mi nube" (F4-09): sin cuentas ni trackers, solo localStorage. */
export const ORIGIN_KEY = 'letra-chica:origin';
const PROVIDERS = ['azure', 'aws', 'gcp'] as const;

/**
 * Marca la nube de origen en <html> (el CSS muestra las notas "Venís de…") y
 * reescribe los links a comparaciones para que arranquen por esa nube.
 */
export function applyOrigin(origin: string): void {
  const root = document.documentElement;
  if ((PROVIDERS as readonly string[]).includes(origin)) root.dataset.origin = origin;
  else delete root.dataset.origin;
  document.querySelectorAll<HTMLAnchorElement>('a[data-pattern-link]').forEach((a) => {
    const def = a.dataset.defaultView!;
    const other = PROVIDERS.find((p) => p !== origin);
    const view = root.dataset.origin ? `${origin}-vs-${other}` : def;
    a.href = a.href.replace(/[^/]+\/$/, `${view}/`);
  });
}
