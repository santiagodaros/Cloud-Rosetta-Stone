# ADR 0006 — Hosting en Vercel

- **Estado:** aceptada (2026-10-07)
- **Reemplaza:** la parte de hosting de [ADR 0002](0002-astro-static-site.md) (GitHub Pages)

## Contexto

El sitio sigue siendo 100 % estático (Astro SSG). El mantenedor creó el proyecto en Vercel:
`https://cloud-rosetta-stone.vercel.app/`.

## Decisión

Publicar en Vercel desde `main`, con el sitio en la raíz del dominio (`BASE_PATH=/`). La configuración vive en
`vercel.json` (build, `trailingSlash`, cache inmutable para `/_astro/`, `no-cache` para el service worker y
headers de seguridad). `astro.config.mjs` toma `VERCEL_PROJECT_PRODUCTION_URL` como `site`, así canonical, OG,
widgets y dataset apuntan al dominio de producción también en los previews. El workflow de GitHub Pages se
borra; un workflow semanal (`rebuild.yml`) dispara un Deploy Hook para que las fechas relativas no se congelen.

## Consecuencias

- **+** Previews por PR, sin habilitar Pages.
- **+** Sin subpath: URLs más cortas para compartir.
- **−** Vercel Hobby es **solo para uso no comercial**. Mientras el proyecto sea comunitario y sin sponsor está
  bien; si aparece un sponsor o se asocia a una empresa hay que pasar a Pro o volver a un hosting estático
  sin esa restricción (Cloudflare Pages, GitHub Pages). El build no depende de Vercel: `pnpm build` genera
  `dist/` igual en cualquier hosting estático.
- **−** Vercel clona con historial corto: el changelog ("Qué cambió") necesita `VERCEL_DEEP_CLONE=true`.
