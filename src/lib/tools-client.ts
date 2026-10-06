/** Acciones de las herramientas (F4-13/F4-14) que comparten las dos páginas. */

export async function copyText(btn: HTMLButtonElement, text: string, done: string) {
  const label = btn.textContent;
  try {
    await navigator.clipboard.writeText(text);
    btn.textContent = `✓ ${done}`;
    setTimeout(() => (btn.textContent = label), 1500);
  } catch {
    /* Sin permiso de portapapeles: queda la descarga. */
  }
}

export function downloadText(filename: string, text: string) {
  const url = URL.createObjectURL(new Blob([text], { type: 'text/markdown;charset=utf-8' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}

export function loadJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

export function saveJson(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* Sin storage (modo privado): vale para esta visita. */
  }
}
