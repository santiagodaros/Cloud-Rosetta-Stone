import type { APIRoute } from 'astro';
import { offlineUrls } from '../lib/offline.ts';

/** Lista que el service worker descarga con "Guardar para usar sin conexión" (F4-19). */
export const GET: APIRoute = () => new Response(JSON.stringify(offlineUrls()), { headers: { 'content-type': 'application/json' } });
