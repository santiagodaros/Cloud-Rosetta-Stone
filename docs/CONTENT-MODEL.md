# Modelo de contenido

La fuente de verdad es [`src/lib/schema.ts`](../src/lib/schema.ts). Este documento explica el *por qué*.

```
content/
├── capabilities/<id>.yaml           ← diccionario: capability canónica → servicio(s) por nube
└── patterns/<slug>/
    ├── pattern.yaml                 ← topología abstracta (una sola, compartida)
    ├── azure.yaml | aws.yaml | gcp.yaml   ← implementación por nube
    └── terraform/<nube>/            ← módulo real: versions.tf, main.tf, variables.tf, outputs.tf, tests/
```

Categorías: `compute-web`, `async-event`, `storage-data`, `networking`, `identity`, `governance`, `observability`.

## Capability (hub-and-spoke)

Una capability es un concepto independiente de la nube (`object-storage`, `workload-identity`). Cada nube
tiene `services: [...]` **o** `gap: {...}`. Un `gap` no es un error: "en AWS no hay un servicio único de
data perimeter" es información valiosa. `caveats` explica dónde se rompe la analogía a nivel concepto.

Con N nubes, hub-and-spoke necesita N entradas por concepto; el mapeo par a par necesitaría N·(N−1).

## Pattern

- `roles`: nodos del diagrama. `actor` (el workload, el usuario) o `capability` (referencia a una capability).
- `edges`: flujo entre roles, con etiqueta opcional.
- `status: draft` permite subir un patrón incompleto (warnings); `published` exige las 3 nubes y su Terraform.

## Implementation (por nube)

- `bindings`: para **cada** rol de tipo capability, `{ service, config?, notes? }` o `{ gap }`.
- `gotchas`: la "letra chica". Campos obligatorios:
  - `severity`: `security | iam | networking | cost | reliability | operations`
  - `sources`: ≥ 1 URL https de un dominio oficial (lista en `OFFICIAL_SOURCE_HOSTS`)
  - `verified_at`: fecha ISO en que alguien leyó las fuentes y confirmó el texto
  - `exams` (opcional): códigos de certificación donde este conocimiento suma
- `cost`: `scales_to_zero` (`yes | no | partial`), `fixed_cost_drivers` y notas. Sin números todavía: los
  precios se calcularán en build (Fase 4) con región y fecha.

## Validaciones cruzadas (`pnpm validate`)

| Regla | Nivel |
|---|---|
| `id` del patrón = nombre de carpeta | error |
| Roles y capabilities referenciadas existen; edges apuntan a roles existentes | error |
| Cada rol capability tiene binding en cada nube; los actores no | error |
| Patrón `published` tiene las 3 implementaciones y los 3 módulos con `main.tf`, `tests/` y versión pinneada | error |
| Gotchas únicos por nube; `verified_at` no futuro | error |
| `verified_at` > 180 días | warning (+ issue semanal) |
| Falta traducción al inglés | warning |

## Textos localizados

`{ es: "...", en: "..." }`. `es` es obligatorio; si falta `en`, la UI muestra el español y lo marca
"sin traducir".
