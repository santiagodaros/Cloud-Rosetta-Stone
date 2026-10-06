import type { APIRoute } from 'astro';
import { llmsFullTxt } from '../lib/llms.ts';

export const GET: APIRoute = ({ site }) =>
  new Response(llmsFullTxt(site), { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
