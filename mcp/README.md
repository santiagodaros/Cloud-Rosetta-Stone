# Letra Chica MCP server

MCP server de **solo lectura** sobre el [dataset de Letra Chica](../docs/DATASET.md). Le da a Claude,
Copilot o cualquier cliente MCP las diferencias documentadas entre Azure, AWS y Google Cloud, cada una con
su fuente oficial y su fecha de verificación, para que las cite en vez de inventarlas.

No necesita credenciales ni guarda nada. Lee los JSON publicados del sitio y los cachea una hora.

## Herramientas

| Herramienta | Para qué |
|---|---|
| `search_gotchas` | Buscar letra chica por palabras clave, con filtros por nube, severidad y examen |
| `get_gotcha` | Traer un gotcha por su `key` estable (`<patrón>/<nube>/<id>`) |
| `list_patterns` | Listar los patrones comparados |
| `compare_pattern` | Ver qué servicio implementa cada rol en cada nube, más los gotchas por nube |
| `lookup_service` | Equivalencias de un servicio entre nubes, con los huecos explícitos |
| `exam_gotchas` | Gotchas de un examen (AZ-700, ANS-C01, PCNE…) y su estado (vigente, se retira, retirado → reemplazo) |

Todas aceptan `lang: "es" | "en"` (default `en`).

## Instalación

```bash
git clone https://github.com/santiagodaros/Cloud-Rosetta-Stone.git
cd Cloud-Rosetta-Stone/mcp
pnpm install --ignore-workspace
pnpm build
```

**Claude Code:**

```bash
claude mcp add letra-chica -- node "$(pwd)/dist/index.js"
```

**Claude Desktop** (`claude_desktop_config.json`) o cualquier cliente que use el mismo formato:

```json
{
  "mcpServers": {
    "letra-chica": {
      "command": "node",
      "args": ["/ruta/a/Cloud-Rosetta-Stone/mcp/dist/index.js"]
    }
  }
}
```

**VS Code** (`.vscode/mcp.json`):

```json
{
  "servers": {
    "letra-chica": { "type": "stdio", "command": "node", "args": ["/ruta/a/Cloud-Rosetta-Stone/mcp/dist/index.js"] }
  }
}
```

## Fuente de datos

Por defecto lee `https://santiagodaros.github.io/Cloud-Rosetta-Stone/api/v1/`. Con `LETRA_CHICA_DATA`
podés apuntarlo a otra URL o a una carpeta local. Por ejemplo, para probar contenido propio antes de
publicarlo:

```bash
pnpm build                                     # en la raíz del repo
LETRA_CHICA_DATA="$(pwd)/dist/api/v1" node mcp/dist/index.js
```

Si el dataset cambia de `schema_version`, el server falla con un mensaje claro en vez de devolver datos mal
interpretados.

## Desarrollo

- `src/core.ts`: búsqueda y formato, sin I/O. Tiene tests en `tests/mcp.test.ts` (corren con `pnpm test`
  en la raíz).
- `src/index.ts`: registro de herramientas con el SDK oficial.
- `pnpm smoke`: prueba de humo end-to-end por stdio contra `dist/api/v1` (la corre CI después del build).
