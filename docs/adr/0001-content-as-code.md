# ADR 0001 — Contenido como código (YAML en el repo), sin base de datos

- **Estado:** aceptada (2026-10-06)
- **Reemplaza:** Supabase + ISR del spec original

## Contexto

El contenido (patrones, gotchas, Terraform) es de solo lectura para los visitantes y lo escriben
contribuidores. El spec original proponía Supabase (PostgreSQL + RLS) con ISR en Next.js.

## Decisión

El contenido vive en `content/` como YAML + archivos `.tf`, validado por un schema Zod
(`src/lib/schema.ts`) y una validación cruzada (`src/lib/content.ts`). El sitio se compila a estático.

## Consecuencias

- **+** Una contribución es un PR: review, diff, historial, CI y atribución gratis.
- **+** Cero cuotas, cero credenciales, cero infraestructura que mantener. Supabase Free además pausa
  proyectos tras 7 días sin actividad, incompatible con "siempre arriba a $0".
- **+** El mismo código valida en CI y alimenta el build: lo que pasa CI es lo que se publica.
- **−** Sin edición desde un panel web. Aceptable: la audiencia contribuidora usa Git.
- **−** Si en el futuro hay datos generados por usuarios (votos, comentarios), se delegan a GitHub
  Discussions/Issues antes de agregar una DB.
