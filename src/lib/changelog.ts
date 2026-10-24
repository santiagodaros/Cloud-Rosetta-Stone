/**
 * "Qué cambió" (F4-10): eventos por gotcha calculados desde el historial de git.
 *
 * Para cada commit que tocó content/patterns se comparan los gotchas contra el
 * commit padre: nuevo, modificado (texto o fuentes), re-verificado (solo cambió
 * verified_at) o eliminado. Sin historial (checkout superficial) devuelve [].
 */
import { execFileSync } from 'node:child_process';
import { parse as parseYaml } from 'yaml';
import { PROVIDERS, type Localized, type Provider } from './schema.ts';

export type ChangeKind = 'added' | 'updated' | 'reverified' | 'removed';

type GotchaSnapshot = { id: string; title: Localized; body: Localized; sources: string[]; verified_at: string };

export type ChangeEvent = {
  kind: ChangeKind;
  commit: string;
  date: string;
  subject: string;
  pattern: string;
  provider: Provider;
  id: string;
  title: Localized;
  /** Texto actual (`added`, `updated`) y anterior (`updated`). */
  before?: Localized;
  after?: Localized;
  sourcesChanged?: boolean;
  verified_at?: string;
};

const git = (args: string[], cwd: string) => execFileSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });

function snapshot(rev: string, cwd: string): Map<string, GotchaSnapshot & { pattern: string; provider: Provider }> {
  const out = new Map<string, GotchaSnapshot & { pattern: string; provider: Provider }>();
  let files: string[];
  try {
    files = git(['ls-tree', '-r', '--name-only', rev, '--', 'content/patterns'], cwd).split('\n');
  } catch {
    return out;
  }
  for (const file of files) {
    const m = file.match(/^content\/patterns\/([^/]+)\/(azure|aws|gcp)\.yaml$/);
    if (!m) continue;
    try {
      const doc = parseYaml(git(['show', `${rev}:${file}`], cwd)) as { gotchas?: GotchaSnapshot[] };
      for (const g of doc.gotchas ?? []) {
        if (!g?.id || !g.title) continue;
        const title = typeof g.title === 'string' ? { es: g.title } : g.title;
        const body = typeof g.body === 'string' ? { es: g.body } : (g.body ?? { es: '' });
        out.set(`${m[1]}/${m[2]}/${g.id}`, { ...g, title, body, sources: g.sources ?? [], verified_at: String(g.verified_at ?? ''), pattern: m[1], provider: m[2] as Provider });
      }
    } catch {
      // Un YAML viejo inválido no rompe el changelog.
    }
  }
  return out;
}

const sameText = (a: Localized, b: Localized) => a.es === b.es && (a.en ?? '') === (b.en ?? '');

export function computeChangelog(cwd = process.cwd()): ChangeEvent[] {
  let log: string;
  try {
    if (git(['rev-parse', '--is-shallow-repository'], cwd).trim() === 'true') return [];
    log = git(['log', '--no-merges', '--format=%H%x09%cs%x09%s', '--', 'content/patterns'], cwd);
  } catch {
    return [];
  }
  const events: ChangeEvent[] = [];
  for (const line of log.split('\n').filter(Boolean)) {
    const [commit, date, subject] = line.split('\t');
    const parent = (() => {
      try {
        return git(['rev-parse', `${commit}^`], cwd).trim();
      } catch {
        return undefined; // commit raíz
      }
    })();
    const after = snapshot(commit, cwd);
    const before = parent ? snapshot(parent, cwd) : new Map();
    const base = { commit: commit.slice(0, 7), date, subject };
    for (const [key, g] of after) {
      const prev = before.get(key);
      const common = { ...base, pattern: g.pattern, provider: g.provider, id: g.id, title: g.title, verified_at: g.verified_at };
      if (!prev) {
        events.push({ kind: 'added', ...common, after: g.body });
      } else if (!sameText(prev.title, g.title) || !sameText(prev.body, g.body) || prev.sources.join() !== g.sources.join()) {
        events.push({ kind: 'updated', ...common, before: prev.body, after: g.body, sourcesChanged: prev.sources.join() !== g.sources.join() });
      } else if (prev.verified_at !== g.verified_at) {
        events.push({ kind: 'reverified', ...common });
      }
    }
    for (const [key, g] of before) {
      if (!after.has(key)) events.push({ kind: 'removed', ...base, pattern: g.pattern, provider: g.provider, id: g.id, title: g.title });
    }
  }
  // git log viene del commit más nuevo al más viejo: se respeta ese orden y,
  // dentro de cada commit, se ordena por patrón y nube.
  const commitOrder = new Map(events.map((e, i) => [e.commit, i]));
  const order = (p: Provider) => PROVIDERS.indexOf(p);
  return events.sort(
    (a, b) => commitOrder.get(a.commit)! - commitOrder.get(b.commit)! || a.pattern.localeCompare(b.pattern) || order(a.provider) - order(b.provider),
  );
}

/** Diff por palabras (LCS) para mostrar qué cambió en un texto. */
export function wordDiff(before: string, after: string): { op: 'same' | 'del' | 'ins'; text: string }[] {
  const a = before.split(/(\s+)/);
  const b = after.split(/(\s+)/);
  const n = a.length;
  const m = b.length;
  const dp = Array.from({ length: n + 1 }, () => new Uint32Array(m + 1));
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
  const out: { op: 'same' | 'del' | 'ins'; text: string }[] = [];
  const push = (op: 'same' | 'del' | 'ins', text: string) => {
    const last = out[out.length - 1];
    if (last?.op === op) last.text += text;
    else out.push({ op, text });
  };
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) { push('same', a[i++]); j++; }
    else if (dp[i + 1][j] >= dp[i][j + 1]) push('del', a[i++]);
    else push('ins', b[j++]);
  }
  while (i < n) push('del', a[i++]);
  while (j < m) push('ins', b[j++]);
  return out;
}

let cached: ChangeEvent[] | undefined;
export const changelog = () => (cached ??= computeChangelog());
