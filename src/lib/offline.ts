/**
 * Qué se guarda con "Guardar para usar sin conexión" (F4-19): las páginas para estudiar y
 * consultar (patrones, práctica, exámenes, diccionario, decisiones). El resto queda en caché
 * a medida que se visita.
 */
import { LOCALES } from './i18n.ts';
import { capabilitiesHref, conceptsHref, decideHref, examsHref, homeHref, href, patternHref, practiceHref, terraformMapHref } from './paths.ts';
import { DEFAULT_VIEW, publishedPatterns, site } from './site.ts';

export function offlineUrls(): string[] {
  const urls = [href('')];
  for (const lang of LOCALES) {
    urls.push(
      homeHref(lang),
      practiceHref(lang),
      examsHref(lang),
      capabilitiesHref(lang),
      conceptsHref(lang),
      terraformMapHref(lang),
      decideHref(lang),
      href(`${lang}/methodology/`),
      href(`${lang}/offline/`),
      ...publishedPatterns.flatMap(({ pattern }) => [patternHref(lang, pattern.id, 'all'), patternHref(lang, pattern.id, DEFAULT_VIEW)]),
      ...site.exams.map((e) => examsHref(lang, e.code)),
      ...(site.decisions ?? []).map((d) => decideHref(lang, d.id)),
    );
  }
  return [...new Set(urls)];
}
