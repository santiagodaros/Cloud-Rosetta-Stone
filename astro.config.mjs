// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// El sitio vive en la raíz de su dominio (Vercel). SITE_URL lo pisa a mano; en Vercel se usa
// el dominio de producción también en los previews, para que canonical y OG apunten al sitio real.
// BASE_PATH solo hace falta si alguna vez se sirve bajo un subpath.
const vercelProd = process.env.VERCEL_PROJECT_PRODUCTION_URL;
const site = process.env.SITE_URL ?? (vercelProd ? `https://${vercelProd}` : 'http://localhost:4321');
const base = process.env.BASE_PATH ?? '/';

export default defineConfig({
  site,
  base,
  trailingSlash: 'ignore',
  build: { format: 'directory' },
  vite: { plugins: [tailwindcss()] },
});
