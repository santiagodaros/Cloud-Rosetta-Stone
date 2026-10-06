import type { APIRoute } from 'astro';
import { datasetIndex, envelope, jsonResponse } from '../../../lib/dataset.ts';

/** Punto de entrada del dataset: versión, conteos y endpoints. */
export const GET: APIRoute = ({ site }) => jsonResponse(envelope(datasetIndex(site)));
