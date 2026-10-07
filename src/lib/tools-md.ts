/**
 * Generadores de Markdown del checklist de migración (F4-13) y del ADR (F4-14).
 *
 * Corre en el navegador: solo importa tipos y `brand.ts`. El orden de nubes y
 * severidades llega dentro de `ToolsData`.
 */
import { BRAND } from './brand.ts';
import type { Provider, Severity } from './schema.ts';

export type ToolBinding =
  | { gap: string }
  | { service: string; config?: string; notes?: string; partial: boolean; from: Partial<Record<Provider, string>> };

export type ToolGotcha = {
  id: string;
  severity: Severity;
  title: string;
  body: string;
  sources: string[];
  verified_at: string;
  roles: string[];
  url: string;
};

export type ToolImpl = {
  bindings: Record<string, ToolBinding>;
  gotchas: ToolGotcha[];
  /** `floor`: piso mensual de lista ya formateado ("USD 12.41"), si hay precios. */
  cost: { scales_to_zero: 'yes' | 'no' | 'partial'; fixed: string[]; notes: string; floor?: string };
};

export type ToolPattern = {
  id: string;
  title: string;
  summary: string;
  problem: string;
  url: string;
  roles: { id: string; label: string; capability: string }[];
  clouds: Partial<Record<Provider, ToolImpl>>;
};

export type ToolTerraform = {
  id: string;
  title: string;
  capability?: string;
  match: 'one-to-one' | 'partial' | 'gap';
  resources: Record<Provider, string[]>;
  notes?: string;
};

export type ToolsData = {
  /** Orden canónico y nombre corto de cada nube. */
  providers: { id: Provider; short: string }[];
  /** Orden de severidad (de más a menos grave). */
  severities: Severity[];
  patterns: ToolPattern[];
  terraform: ToolTerraform[];
};

/**
 * Textos de las herramientas: strings planos con `{placeholders}`, así se serializan
 * al cliente sin funciones.
 */
export type ToolStrings = {
  severity: Record<Severity, string>;
  scales: Record<'yes' | 'no' | 'partial', string>;
  tfMatch: Record<ToolTerraform['match'], string>;
  gap: string;
  partial: string;
  sources: string;
  verified: string;
  via: string;
  migTitle: string;
  migRoles: string;
  migGotchas: string;
  migTerraform: string;
  migCost: string;
  migFixedCost: string;
  migCostChange: string;
  migFloorChange: string;
  adrFloor: string;
  adrContext: string;
  adrDrivers: string;
  adrOptions: string;
  adrOutcome: string;
  adrChosen: string;
  adrConsequences: string;
  adrFinePrint: string;
  adrProsCons: string;
  adrMoreInfo: string;
  adrGood: string;
  adrBad: string;
  adrNeutral: string;
  adrScalesGood: string;
  adrFixedBad: string;
  adrScalesPartial: string;
  adrGapBad: string;
  adrPartialNeutral: string;
  adrGotchaCount: string;
  adrNoRationale: string;
  adrPatternLink: string;
};

export const fill = (tpl: string, vars: Record<string, string | number>) =>
  tpl.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));

const oneLine = (s: string) => s.replace(/\s+/g, ' ').trim();
const short = (data: ToolsData, p: Provider) => data.providers.find((x) => x.id === p)?.short ?? p;
const bySeverity = (data: ToolsData) => (a: ToolGotcha, b: ToolGotcha) =>
  data.severities.indexOf(a.severity) - data.severities.indexOf(b.severity) || a.id.localeCompare(b.id);
const svc = (b: ToolBinding | undefined, S: ToolStrings, config = true) =>
  !b ? '—' : 'gap' in b ? S.gap : `${b.service}${config && b.config ? ` (${b.config})` : ''}${b.partial ? ' ≈' : ''}`;

// ---------------------------------------------------------------------------
// F4-13: checklist de migración
// ---------------------------------------------------------------------------

export type ChecklistItem = { id: string; text: string; tag?: string; detail?: string; sources?: string[]; verified?: string; href?: string };
export type ChecklistSection = { kind: 'roles' | 'gotchas' | 'terraform' | 'cost'; title: string; items: ChecklistItem[] };
export type ChecklistPattern = { id: string; title: string; url: string; sections: ChecklistSection[] };
export type Checklist = { from: Provider; to: Provider; title: string; patterns: ChecklistPattern[] };

export type MigrationInput = { from: Provider; to: Provider; patterns: string[] };

/** Prefijo de los ids de ítem: el estado de los checkboxes es por par origen→destino. */
export const checklistKey = (from: Provider, to: Provider) => `${from}>${to}`;

export function buildChecklist(data: ToolsData, { from, to, patterns }: MigrationInput, S: ToolStrings): Checklist {
  const key = checklistKey(from, to);
  const selected = data.patterns.filter((p) => patterns.includes(p.id));
  return {
    from,
    to,
    title: fill(S.migTitle, { from: short(data, from), to: short(data, to) }),
    patterns: selected.map((p) => {
      const src = p.clouds[from];
      const dst = p.clouds[to];
      const id = (...parts: string[]) => [key, p.id, ...parts].join('/');

      const roles: ChecklistItem[] = p.roles.map((r) => {
        const a = src?.bindings[r.id];
        const b = dst?.bindings[r.id];
        // Prioridad: la nota curada "venís de <origen>"; si no hay, la nota de equivalencia parcial o del hueco.
        const detail = b && 'gap' in b ? b.gap : b?.from[from] ?? (b?.partial ? b.notes : undefined);
        return {
          id: id('role', r.id),
          text: `${r.label}: ${svc(a, S)} → ${svc(b, S)}`,
          ...(detail ? { detail: oneLine(detail) } : {}),
        };
      });

      const gotchas: ChecklistItem[] = [...(dst?.gotchas ?? [])].sort(bySeverity(data)).map((g) => ({
        id: id('gotcha', g.id),
        tag: S.severity[g.severity],
        text: g.title,
        detail: g.body,
        sources: g.sources,
        verified: g.verified_at,
        href: g.url,
      }));

      const caps = new Set(p.roles.map((r) => r.capability));
      const terraform: ChecklistItem[] = data.terraform
        .filter((e) => e.capability && caps.has(e.capability))
        .map((e) => {
          const res = (pr: Provider) => (e.resources[pr].length ? e.resources[pr].map((x) => `\`${x}\``).join(', ') : S.gap);
          return {
            id: id('tf', e.id),
            text: `${e.title} (${S.tfMatch[e.match]}): ${res(from)} → ${res(to)}`,
            ...(e.notes ? { detail: e.notes } : {}),
          };
        });

      const cost: ChecklistItem[] = [];
      if (src && dst) {
        cost.push({
          id: id('cost', 'model'),
          text: fill(S.migCostChange, { from: S.scales[src.cost.scales_to_zero], to: S.scales[dst.cost.scales_to_zero] }),
          detail: src.cost.floor && dst.cost.floor ? `${fill(S.migFloorChange, { from: src.cost.floor, to: dst.cost.floor })} ${dst.cost.notes}` : dst.cost.notes,
        });
        dst.cost.fixed.forEach((d, i) => cost.push({ id: id('cost', `fixed-${i}`), text: fill(S.migFixedCost, { item: d }) }));
      }

      const sections: ChecklistSection[] = [
        { kind: 'roles', title: S.migRoles, items: roles },
        { kind: 'gotchas', title: fill(S.migGotchas, { to: short(data, to) }), items: gotchas },
        { kind: 'terraform', title: S.migTerraform, items: terraform },
        { kind: 'cost', title: S.migCost, items: cost },
      ];
      return { id: p.id, title: p.title, url: p.url, sections: sections.filter((s) => s.items.length > 0) };
    }),
  };
}

/** Checklist en Markdown con task lists de GitHub (`- [ ]` / `- [x]`). */
export function checklistMarkdown(c: Checklist, checked: ReadonlySet<string>, S: ToolStrings): string {
  const lines = [`# ${c.title}`, ''];
  for (const p of c.patterns) {
    lines.push(`## [${p.title}](${p.url})`, '');
    for (const s of p.sections) {
      lines.push(`### ${s.title}`, '');
      for (const it of s.items) {
        const title = it.href ? `[${it.text}](${it.href})` : it.text;
        lines.push(`- [${checked.has(it.id) ? 'x' : ' '}] ${it.tag ? `**${it.tag}** · ` : ''}${title}`);
        if (it.detail) lines.push(`  ${it.detail}`);
        if (it.sources?.length) lines.push(`  ${S.sources}: ${it.sources.map((u) => `<${u}>`).join(' · ')}${it.verified ? ` · ${S.verified} ${it.verified}` : ''}`);
      }
      lines.push('');
    }
  }
  lines.push(`${S.via} [${BRAND.name}](${BRAND.site}) · CC BY-SA 4.0`);
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// F4-14: ADR en formato MADR 4
// ---------------------------------------------------------------------------

export type AdrInput = {
  pattern: string;
  chosen: Provider;
  title?: string;
  status: 'proposed' | 'accepted' | 'rejected' | 'deprecated' | 'superseded';
  date: string;
  drivers: string[];
  rationale: string;
};

function severityCounts(data: ToolsData, gotchas: ToolGotcha[], S: ToolStrings): string {
  return data.severities.map((s) => [s, gotchas.filter((g) => g.severity === s).length] as const)
    .filter(([, n]) => n > 0)
    .map(([s, n]) => `${n} ${S.severity[s]}`)
    .join(', ');
}

function prosCons(data: ToolsData, p: ToolPattern, impl: ToolImpl, S: ToolStrings): string[] {
  const out: string[] = [];
  const { cost } = impl;
  if (cost.scales_to_zero === 'yes') out.push(`${S.adrGood}, ${S.adrScalesGood}`);
  else if (cost.scales_to_zero === 'partial') out.push(`${S.adrNeutral}, ${S.adrScalesPartial}`);
  for (const d of cost.fixed) out.push(`${S.adrBad}, ${fill(S.adrFixedBad, { item: d })}`);
  if (cost.floor) out.push(`${S.adrNeutral}, ${fill(S.adrFloor, { floor: cost.floor })}`);
  for (const r of p.roles) {
    const b = impl.bindings[r.id];
    if (b && 'gap' in b) out.push(`${S.adrBad}, ${fill(S.adrGapBad, { role: r.label, note: oneLine(b.gap) })}`);
    else if (b?.partial) out.push(`${S.adrNeutral}, ${fill(S.adrPartialNeutral, { role: r.label, service: b.service, note: oneLine(b.notes ?? '') })}`);
  }
  if (impl.gotchas.length) out.push(`${S.adrNeutral}, ${fill(S.adrGotchaCount, { n: impl.gotchas.length, list: severityCounts(data, impl.gotchas, S) })}`);
  return out;
}

/** ADR en MADR 4 (https://adr.github.io/madr/): contexto, opciones, decisión, consecuencias. */
export function adrMarkdown(data: ToolsData, input: AdrInput, S: ToolStrings): string {
  const p = data.patterns.find((x) => x.id === input.pattern);
  if (!p) throw new Error(`patrón desconocido: ${input.pattern}`);
  const options = data.providers.map((x) => x.id).filter((pr) => p.clouds[pr]);
  const chosen = p.clouds[input.chosen];
  if (!chosen) throw new Error(`${input.pattern} no tiene implementación en ${input.chosen}`);
  const optionName = (pr: Provider) => `${short(data, pr)}: ${p.roles.map((r) => svc(p.clouds[pr]!.bindings[r.id], S, false)).join(' + ')}`;
  const drivers = input.drivers.map(oneLine).filter(Boolean);
  const rationale = oneLine(input.rationale) || S.adrNoRationale;

  const lines = [
    '---',
    `status: ${input.status}`,
    `date: ${input.date}`,
    '---',
    '',
    `# ${oneLine(input.title ?? '') || `${p.title}: ${short(data, input.chosen)}`}`,
    '',
    `## ${S.adrContext}`,
    '',
    p.problem,
    '',
  ];
  if (drivers.length) lines.push(`## ${S.adrDrivers}`, '', ...drivers.map((d) => `- ${d}`), '');
  lines.push(`## ${S.adrOptions}`, '', ...options.map((pr) => `- ${optionName(pr)}`), '');
  lines.push(
    `## ${S.adrOutcome}`,
    '',
    fill(S.adrChosen, { option: optionName(input.chosen), rationale }),
    '',
    `### ${S.adrConsequences}`,
    '',
    ...prosCons(data, p, chosen, S).map((x) => `- ${x}`),
    '',
    `### ${S.adrFinePrint}`,
    '',
    ...[...chosen.gotchas].sort(bySeverity(data)).flatMap((g) => [
      `- [ ] **${S.severity[g.severity]}** · [${g.title}](${g.url})`,
      `  ${g.body}`,
      `  ${S.sources}: ${g.sources.map((u) => `<${u}>`).join(' · ')} · ${S.verified} ${g.verified_at}`,
    ]),
    '',
    `## ${S.adrProsCons}`,
    '',
  );
  for (const pr of options) {
    const impl = p.clouds[pr]!;
    lines.push(`### ${short(data, pr)}`, '', `| ${p.roles.map((r) => r.label.replace(/\|/g, '\\|')).join(' | ')} |`, `|${p.roles.map(() => '---|').join('')}`);
    lines.push(`| ${p.roles.map((r) => svc(impl.bindings[r.id], S).replace(/\|/g, '\\|')).join(' | ')} |`, '');
    lines.push(...prosCons(data, p, impl, S).map((x) => `- ${x}`), '');
  }
  lines.push(`## ${S.adrMoreInfo}`, '', `- ${S.adrPatternLink}: <${p.url}>`, `- ${S.via} [${BRAND.name}](${BRAND.site}) · CC BY-SA 4.0`);
  return lines.join('\n');
}

