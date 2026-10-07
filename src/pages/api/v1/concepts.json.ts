import type { APIRoute } from 'astro';
import { envelope, jsonResponse } from '../../../lib/dataset.ts';
import { site } from '../../../lib/site.ts';

/** Dataset abierto: diccionario de conceptos (jerarquía, red, zonas, identidad, metadatos). */
export const GET: APIRoute = () => jsonResponse(envelope({ concepts: site.concepts }));
