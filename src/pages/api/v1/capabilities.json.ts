import type { APIRoute } from 'astro';
import { site } from '../../../lib/site.ts';

/** Dataset abierto: diccionario de capabilities (hub-and-spoke por nube). */
export const GET: APIRoute = () =>
  new Response(JSON.stringify({ schema_version: 1, license: 'CC-BY-SA-4.0', capabilities: site.capabilities }, null, 2), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
