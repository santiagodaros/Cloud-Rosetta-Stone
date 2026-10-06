# Dataset abierto

Todo el contenido publicado está disponible como JSON estático, generado en cada build (no hay API con
estado ni límites de uso). Licencia **CC BY-SA 4.0**: citá "Letra Chica" con link.

| Endpoint | Contenido |
|---|---|
| `/api/v1/index.json` | Versión, conteos y URLs de los demás endpoints |
| `/api/v1/gotchas.json` | Lista plana de gotchas: `key`, `pattern`, `provider`, `severity`, `title`, `body`, `sources`, `verified_at`, `exams`, `url.{es,en}` |
| `/api/v1/patterns.json` | Patrones con roles, edges, bindings por nube, gotchas, modelo de costo y versiones de providers |
| `/api/v1/capabilities.json` | Diccionario de capabilities, con huecos (`gap`) explícitos |
| `/api/v1/exams.json` | Catálogo de exámenes con `status` derivado y las `key` de sus gotchas |
| `/llms.txt` | Índice para asistentes ([llmstxt.org](https://llmstxt.org)) |
| `/llms-full.txt` | Todos los gotchas como texto, en inglés y español, con fuente, fecha y link |

## Contrato

- Toda respuesta JSON trae `schema_version`, `generated_at` (ISO 8601, momento del build), `license` y
  `attribution`.
- `schema_version` sube **solo** con cambios incompatibles: renombrar o quitar un campo, o cambiar su tipo.
  Agregar campos no la cambia; ignorá los que no conozcas.
- `key` (`<patrón>/<nube>/<gotcha>`) es estable: si un gotcha se reescribe, conserva su `key`. Si se
  elimina, deja de aparecer.
- Los textos localizados son `{ "es": "...", "en": "..." }`. `es` siempre está; `en` puede faltar en
  contenido recién agregado.
- `verified_at` es la fecha en que una persona leyó las fuentes. Un gotcha con más de 180 días se considera
  "a re-verificar" (y el sitio lo marca).

## Uso desde asistentes

El [MCP server](../mcp/README.md) expone este mismo dataset como herramientas de solo lectura para Claude,
Copilot y cualquier cliente MCP.
