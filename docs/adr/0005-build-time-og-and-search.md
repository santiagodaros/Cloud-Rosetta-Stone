# ADR 0005 — OG images y búsqueda generadas en build time

- **Estado:** aceptada (2026-10-06)

## Contexto

La distribución principal es LinkedIn y Slack: un link sin preview no se clickea. Y con 3 patrones × 3 nubes
el contenido ya necesita búsqueda. El sitio es estático (ADR 0002) y no tiene backend.

## Decisión

- **OG images:** satori (HTML → SVG) + resvg (SVG → PNG) como endpoints estáticos de Astro. Una imagen por
  patrón × vista × idioma, con título, nubes comparadas y cantidad de gotchas. Fuente Inter desde
  `@fontsource/inter` (sin descargas en build).
- **Búsqueda:** Pagefind después de `astro build`. Se indexa solo la vista "las tres" de cada patrón (para no
  duplicar resultados por par), el diccionario y la metodología; HCL, badges y diagramas se excluyen con
  `data-pagefind-ignore`. Índice separado por idioma.

## Consecuencias

- **+** Cero servicios externos, cero costo, funciona en GitHub Pages.
- **+** Cada comparación compartida tiene su propio preview: refuerza la estrategia editorial.
- **−** El build tarda unos segundos más por imagen; con cientos de patrones habría que cachear o generar
  solo las vistas canónicas.
