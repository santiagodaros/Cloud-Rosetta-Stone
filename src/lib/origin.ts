/**
 * "Tu nube de origen" (F4-09): qué cambia en cada rol para quien viene de otra nube.
 * Combina una nota automática (qué usabas allá) con la curada en `binding.from`.
 */
import type { PatternBundle } from './content.ts';
import { PROVIDER_META, t, ui, type Locale } from './i18n.ts';
import { PROVIDERS, type Provider } from './schema.ts';

export type OriginNote = { from: Provider; used: string; curated?: string };

export function originNotes(bundle: PatternBundle, provider: Provider, roleId: string, lang: Locale): OriginNote[] {
  const s = ui(lang);
  const here = bundle.implementations[provider]?.bindings[roleId];
  return PROVIDERS.filter((o) => o !== provider).map((o) => {
    const there = bundle.implementations[o]?.bindings[roleId];
    const used = !there || 'gap' in there ? s.originGap(PROVIDER_META[o].short) : s.originUsed(PROVIDER_META[o].short, t(there.service, lang));
    const curated = here && 'service' in here ? here.from?.[o] : undefined;
    return { from: o, used, curated: curated ? t(curated, lang) : undefined };
  });
}
