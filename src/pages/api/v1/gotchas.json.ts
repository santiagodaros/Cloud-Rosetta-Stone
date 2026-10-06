import type { APIRoute } from 'astro';
import { envelope, flatGotchas, jsonResponse } from '../../../lib/dataset.ts';

/** Todos los gotchas publicados en una lista plana, con deep link por idioma. */
export const GET: APIRoute = ({ site }) => jsonResponse(envelope({ gotchas: flatGotchas(site) }));
