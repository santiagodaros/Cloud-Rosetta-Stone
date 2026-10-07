import type { APIRoute } from 'astro';
import { href } from '../lib/paths.ts';

/**
 * Service worker (F4-19). Sin dependencias ni build aparte: se genera con el `base` del sitio.
 *
 * - Navegación: red primero (contenido fresco) y caché si no hay red; si la página nunca se
 *   guardó, la página "sin conexión" del idioma.
 * - /_astro/ (hash en el nombre, inmutable): caché primero.
 * - Resto (JSON del dataset, Pagefind, íconos): stale-while-revalidate.
 * - Mensaje "save-offline": descarga offline-urls.json, cada página y sus CSS/JS/fuentes.
 *
 * Los nombres de caché son estables entre deploys para no perder lo guardado; los assets que
 * ya no usa ninguna página guardada se podan al guardar.
 */
const sw = (base: string) => `'use strict';
const BASE = ${JSON.stringify(base)};
const PAGES = 'lc-pages-v1';
const ASSETS = 'lc-assets-v1';
const SHELL = [BASE, BASE + 'es/offline/', BASE + 'en/offline/', BASE + 'favicon.svg', BASE + 'manifest.webmanifest'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(PAGES).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('lc-') && k !== PAGES && k !== ASSETS).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

const isAsset = (url) => url.pathname.startsWith(BASE + '_astro/');
const offlinePage = (url) => BASE + (url.pathname.startsWith(BASE + 'en/') ? 'en' : 'es') + '/offline/';

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin || !url.pathname.startsWith(BASE)) return;

  if (isAsset(url)) {
    event.respondWith(
      caches.open(ASSETS).then((c) =>
        c.match(req).then((hit) => hit || fetch(req).then((res) => (res.ok && c.put(req, res.clone()), res))),
      ),
    );
    return;
  }

  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res.ok) caches.open(PAGES).then((c) => c.put(req, res.clone()));
          return res;
        })
        .catch(() =>
          caches.open(PAGES).then((c) => c.match(req, { ignoreSearch: true }).then((hit) => hit || c.match(offlinePage(url)))),
        ),
    );
    return;
  }

  event.respondWith(
    caches.open(PAGES).then((c) =>
      c.match(req).then((hit) => {
        const net = fetch(req)
          .then((res) => (res.ok && c.put(req, res.clone()), res))
          .catch(() => hit);
        return hit || net;
      }),
    ),
  );
});

// Recursos que referencia una página, una hoja de estilos o un chunk JS (import entre chunks).
function assetsIn(text, from) {
  const out = new Set();
  const re = /(?:href|src)="([^"]+)"|url\\(\\s*['"]?([^'")]+)['"]?\\s*\\)|(?:from|import)\\s*\\(?\\s*["'](\\.{1,2}\\/[^"']+)["']/g;
  for (const m of text.matchAll(re)) {
    const raw = m[1] || m[2] || m[3];
    if (!raw || raw.startsWith('data:')) continue;
    const u = new URL(raw, from);
    if (u.origin === self.location.origin && isAsset(u)) out.add(u.href);
  }
  return out;
}

async function saveOffline(client) {
  const urls = await (await fetch(BASE + 'offline-urls.json', { cache: 'no-store' })).json();
  const pages = await caches.open(PAGES);
  const assets = await caches.open(ASSETS);
  const used = new Set();
  let done = 0;
  for (const u of urls) {
    try {
      const res = await fetch(u, { cache: 'no-store' });
      if (res.ok) {
        await pages.put(u, res.clone());
        for (const a of assetsIn(await res.text(), new URL(u, self.location.origin))) used.add(a);
      }
    } catch (e) {}
    done += 1;
    client && client.postMessage({ type: 'offline-progress', done, total: urls.length });
  }
  // Recorrido de assets: CSS y JS pueden referenciar otros (fuentes, chunks importados).
  const queue = [...used];
  while (queue.length) {
    const a = queue.shift();
    try {
      let res = await assets.match(a);
      if (!res) {
        res = await fetch(a);
        if (!res.ok) continue;
        await assets.put(a, res.clone());
      }
      if (/\\.(css|js)$/.test(new URL(a).pathname)) {
        for (const f of assetsIn(await res.clone().text(), new URL(a))) if (!used.has(f)) (used.add(f), queue.push(f));
      }
    } catch (e) {}
  }
  // Poda: CSS/JS de deploys viejos que ya no referencia ninguna página en caché (las fuentes se quedan).
  const keep = new Set(used);
  for (const req of await pages.keys()) {
    const r = await pages.match(req);
    if (r && (r.headers.get('content-type') || '').includes('html')) for (const a of assetsIn(await r.text(), new URL(req.url))) keep.add(a);
  }
  for (const req of await assets.keys()) {
    if (/\.(js|css)$/.test(new URL(req.url).pathname) && !keep.has(req.url)) await assets.delete(req);
  }
  client && client.postMessage({ type: 'offline-done', total: urls.length });
}

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'save-offline') event.waitUntil(saveOffline(event.source));
});
`;

export const GET: APIRoute = () => new Response(sw(href('')), { headers: { 'content-type': 'text/javascript' } });
