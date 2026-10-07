# ADR 0002 — Astro, salida 100 % estática, GitHub Pages

- **Estado:** aceptada (2026-10-06). El hosting pasó a Vercel: ver [ADR 0006](0006-hosting-vercel.md)
- **Reemplaza:** Next.js 15 + Vercel Hobby del spec original

## Contexto

Es un sitio de contenido. El spec proponía Next.js 15 (la línea actual es 16.x) sobre Vercel Hobby,
que está limitado a uso no comercial.

## Decisión

Astro 7 con `output` estático, Tailwind 4 y Shiki (incluido en Astro) para HCL. Deploy a GitHub Pages
con un workflow que además re-publica semanalmente.

## Consecuencias

- **+** HTML estático, casi sin JS (solo el botón "copiar"). Rápido y accesible.
- **+** Hosting gratuito sin restricción comercial y sin cuenta adicional.
- **+** Mismo stack que isbetter.ai (Astro), referencia de UX del proyecto.
- **−** Sin SSR: cualquier feature dinámica tiene que resolverse en build o en el cliente.
- **Alternativa válida:** Cloudflare Pages si se necesita un dominio propio con reglas de cache/redirect.
