import type { APIRoute } from 'astro';
import { envelope, jsonResponse } from '../../../lib/dataset.ts';
import { site } from '../../../lib/site.ts';

/** Dataset abierto: diccionario de capabilities (hub-and-spoke por nube). */
export const GET: APIRoute = () => jsonResponse(envelope({ capabilities: site.capabilities }));
