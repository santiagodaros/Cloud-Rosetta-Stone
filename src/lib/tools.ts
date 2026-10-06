/**
 * Checklist de migración (F4-13) y generador de ADR (F4-14).
 *
 * `toolsData` corre en build time y deja todo localizado en un JSON que viaja a la página.
 * Los generadores viven en `tools-md.ts`, sin dependencias de runtime (ni zod ni el
 * diccionario de i18n), para que el bundle del cliente quede chico.
 */
import { PROVIDER_META, t, ui, type Locale } from './i18n.ts';
import type { PatternBundle } from './content.ts';
import { PROVIDERS, SEVERITIES, type TerraformMap } from './schema.ts';
import type { ToolImpl, ToolPattern, ToolStrings, ToolTerraform, ToolsData } from './tools-md.ts';

export * from './tools-md.ts';

/** URL absoluta de un patrón (vista "all") con ancla opcional. */
export type UrlFor = (patternId: string, anchor?: string) => string;

export function toolsData(bundles: PatternBundle[], tfMap: TerraformMap | undefined, lang: Locale, urlFor: UrlFor): ToolsData {
  const patterns = bundles.map(({ pattern, implementations }): ToolPattern => {
    const clouds: ToolPattern['clouds'] = {};
    for (const p of PROVIDERS) {
      const impl = implementations[p];
      if (!impl) continue;
      const bindings: ToolImpl['bindings'] = {};
      for (const [role, b] of Object.entries(impl.bindings)) {
        bindings[role] =
          'gap' in b
            ? { gap: t(b.gap, lang) }
            : {
                service: t(b.service, lang),
                ...(b.config ? { config: t(b.config, lang) } : {}),
                ...(b.notes ? { notes: t(b.notes, lang) } : {}),
                partial: b.equivalence === 'partial',
                from: Object.fromEntries(Object.entries(b.from ?? {}).map(([k, v]) => [k, t(v, lang)])),
              };
      }
      clouds[p] = {
        bindings,
        gotchas: impl.gotchas.map((g) => ({
          id: g.id,
          severity: g.severity,
          title: t(g.title, lang),
          body: t(g.body, lang).replace(/\s+/g, ' ').trim(),
          sources: g.sources,
          verified_at: g.verified_at,
          roles: g.roles,
          url: urlFor(pattern.id, `${p}-${g.id}`),
        })),
        cost: {
          scales_to_zero: impl.cost.scales_to_zero,
          fixed: impl.cost.fixed_cost_drivers.map((d) => t(d, lang)),
          notes: t(impl.cost.notes, lang).replace(/\s+/g, ' ').trim(),
        },
      };
    }
    return {
      id: pattern.id,
      title: t(pattern.title, lang),
      summary: t(pattern.summary, lang),
      problem: t(pattern.problem, lang).replace(/\s+/g, ' ').trim(),
      url: urlFor(pattern.id),
      roles: pattern.roles.flatMap((r) => (r.kind === 'capability' ? [{ id: r.id, label: t(r.label, lang), capability: r.capability }] : [])),
      clouds,
    };
  });
  const terraform = (tfMap?.entries ?? []).map(
    (e): ToolTerraform => ({
      id: e.id,
      title: t(e.title, lang),
      ...(e.capability ? { capability: e.capability } : {}),
      match: e.match,
      resources: e.resources,
      ...(e.notes ? { notes: t(e.notes, lang).replace(/\s+/g, ' ').trim() } : {}),
    }),
  );
  return {
    providers: PROVIDERS.map((id) => ({ id, short: PROVIDER_META[id].short })),
    severities: [...SEVERITIES],
    patterns,
    terraform,
  };
}

export const toolStrings = (lang: Locale): ToolStrings => {
  const s = ui(lang);
  return { ...s.tools, severity: s.severity, tfMatch: s.tfMatch };
};
