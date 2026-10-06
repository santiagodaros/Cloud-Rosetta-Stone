/**
 * Layout de diagramas en build time con ELK.
 *
 * La topología del patrón es una sola; el layout se calcula una vez con el
 * tamaño de nodo más grande entre todas las nubes, así los diagramas quedan
 * idénticos en posición y el ojo compara solo lo que cambia: el servicio.
 * El resultado se renderiza como SVG estático (sin JS en el cliente).
 */
import ELK from 'elkjs/lib/elk.bundled.js';
import type { ElkNode } from 'elkjs/lib/elk-api.js';
import type { Implementation, Pattern, Provider } from './schema.ts';
import { PROVIDERS } from './schema.ts';
import { t, type Locale } from './i18n.ts';

export const NODE_WIDTH = 176;
const LINE_HEIGHT = 16;
const NODE_PADDING_Y = 14;
const ROLE_LABEL_HEIGHT = 16;
const CHARS_PER_LINE = 22;
const EDGE_LABEL_CHAR_WIDTH = 6.4;

export type NodeContent = { role: string; lines: string[]; gap: boolean; actor: boolean; partial: boolean };

export type DiagramLayout = {
  width: number;
  height: number;
  nodes: { id: string; x: number; y: number; width: number; height: number }[];
  edges: { id: string; from: string; to: string; path: string; label?: { text: string; x: number; y: number } }[];
};

/** Corta texto en líneas de ~CHARS_PER_LINE sin partir palabras. */
export function wrap(text: string, max = CHARS_PER_LINE): string[] {
  const lines: string[] = [];
  let current = '';
  for (const word of text.split(/\s+/).filter(Boolean)) {
    if (current && `${current} ${word}`.length > max) {
      lines.push(current);
      current = word;
    } else {
      current = current ? `${current} ${word}` : word;
    }
  }
  if (current) lines.push(current);
  return lines.length ? lines : [''];
}

/** Texto de cada nodo para una nube concreta. */
export function nodeContents(pattern: Pattern, impl: Implementation | undefined, lang: Locale, gapLabel: string) {
  const out: Record<string, NodeContent> = {};
  for (const role of pattern.roles) {
    if (role.kind === 'actor') {
      out[role.id] = { role: t(role.label, lang), lines: [], gap: false, actor: true, partial: false };
      continue;
    }
    const b = impl?.bindings[role.id];
    const isGap = !b || 'gap' in b;
    out[role.id] = {
      role: t(role.label, lang),
      lines: isGap ? [gapLabel] : wrap(t(b.service, lang)),
      gap: isGap,
      actor: false,
      partial: !isGap && b.equivalence === 'partial',
    };
  }
  return out;
}

const nodeHeight = (c: NodeContent) =>
  NODE_PADDING_Y * 2 + (c.actor ? LINE_HEIGHT : ROLE_LABEL_HEIGHT + c.lines.length * LINE_HEIGHT);

const elk = new ELK();

export async function layoutPattern(
  pattern: Pattern,
  implementations: Partial<Record<Provider, Implementation>>,
  lang: Locale,
  gapLabel: string,
): Promise<DiagramLayout> {
  const contents = PROVIDERS.map((p) => nodeContents(pattern, implementations[p], lang, gapLabel));
  const heights = Object.fromEntries(
    pattern.roles.map((r) => [r.id, Math.max(...contents.map((c) => nodeHeight(c[r.id])))]),
  );

  const input: ElkNode = {
    id: 'root',
    layoutOptions: {
      'elk.algorithm': 'layered',
      'elk.direction': 'DOWN',
      'elk.edgeRouting': 'ORTHOGONAL',
      'elk.layered.spacing.nodeNodeBetweenLayers': '40',
      'elk.spacing.nodeNode': '22',
      'elk.spacing.edgeLabel': '4',
      'elk.edgeLabels.inline': 'false',
      'elk.layered.nodePlacement.strategy': 'NETWORK_SIMPLEX', 'elk.layered.layering.strategy': 'LONGEST_PATH_SOURCE',
    },
    children: pattern.roles.map((r) => ({ id: r.id, width: NODE_WIDTH, height: heights[r.id] })),
    edges: pattern.edges.map((e, i) => {
      const text = e.label ? t(e.label, lang) : undefined;
      return {
        id: `e${i}`,
        sources: [e.from],
        targets: [e.to],
        labels: text ? [{ id: `l${i}`, text, width: text.length * EDGE_LABEL_CHAR_WIDTH + 8, height: 16 }] : [],
      };
    }),
  };
  const graph = await elk.layout(input);

  const nodes = (graph.children ?? []).map((n) => ({
    id: n.id,
    x: n.x ?? 0,
    y: n.y ?? 0,
    width: n.width ?? NODE_WIDTH,
    height: n.height ?? 0,
  }));

  const edges = (graph.edges ?? []).map((e) => {
    const src = pattern.edges[Number(e.id.slice(1))];
    const s = e.sections?.[0];
    const points = s ? [s.startPoint, ...(s.bendPoints ?? []), s.endPoint] : [];
    const path = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
    const l = e.labels?.[0];
    return {
      id: e.id,
      from: src.from,
      to: src.to,
      path,
      label: l?.text ? { text: l.text, x: (l.x ?? 0) + (l.width ?? 0) / 2, y: (l.y ?? 0) + (l.height ?? 0) / 2 } : undefined,
    };
  });

  return { width: graph.width ?? 0, height: graph.height ?? 0, nodes, edges };
}
