import type { APIRoute } from 'astro';
import { BRAND } from '../../lib/brand.ts';
import { changelog, wordDiff } from '../../lib/changelog.ts';
import { LOCALES, PROVIDER_META, t, ui, type Locale } from '../../lib/i18n.ts';
import { href, patternHref } from '../../lib/paths.ts';

export function getStaticPaths() {
  return LOCALES.map((lang) => ({ params: { lang } }));
}

const MAX_ENTRIES = 50;
const esc = (x: string) => x.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** Feed Atom de "Qué cambió": un entry por gotcha nuevo, corregido, re-verificado o eliminado. */
export const GET: APIRoute = ({ params, site }) => {
  const lang = params.lang as Locale;
  const s = ui(lang);
  const abs = (path: string) => new URL(path, site ?? BRAND.site).href;
  const changesUrl = abs(href(`${lang}/changes/`));
  const events = changelog().slice(0, MAX_ENTRIES);
  const updated = events[0] ? `${events[0].date}T00:00:00Z` : new Date().toISOString();

  const entries = events.map((e) => {
    const anchor = `${e.commit}-${e.pattern}-${e.provider}-${e.id}`;
    const link = e.kind === 'removed' ? `${changesUrl}#${anchor}` : `${abs(patternHref(lang, e.pattern, 'all'))}#${e.provider}-${e.id}`;
    const title = `[${s.changeKind[e.kind]}] [${PROVIDER_META[e.provider].short}] ${t(e.title, lang)}`;
    const body =
      e.kind === 'updated' && e.before && e.after
        ? wordDiff(t(e.before, lang), t(e.after, lang))
            .map((p) => (p.op === 'same' ? esc(p.text) : p.op === 'del' ? `<del>${esc(p.text)}</del>` : `<ins>${esc(p.text)}</ins>`))
            .join('')
        : e.after
          ? `${esc(t(e.after, lang))}<p><small>${esc(e.subject)}</small></p>`
          : esc(e.subject);
    return `  <entry>
    <id>${esc(`${changesUrl}#${anchor}`)}</id>
    <title>${esc(title)}</title>
    <link href="${esc(link)}"/>
    <updated>${e.date}T00:00:00Z</updated>
    <content type="html">${esc(body)}</content>
  </entry>`;
  });

  const xml = `<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="${lang}">
  <id>${esc(changesUrl)}</id>
  <title>${esc(`${BRAND.name} — ${s.changesTitle}`)}</title>
  <link rel="self" href="${esc(abs(href(`${lang}/feed.xml`)))}"/>
  <link href="${esc(changesUrl)}"/>
  <updated>${updated}</updated>
  <rights>CC BY-SA 4.0</rights>
${entries.join('\n')}
</feed>
`;
  return new Response(xml, { headers: { 'Content-Type': 'application/atom+xml; charset=utf-8' } });
};
