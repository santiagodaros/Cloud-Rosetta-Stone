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
- `paths` (opcional): recorridos predefinidos para el diagrama interactivo (`{ id, label, roles: [...] }`).
  Cada par de roles consecutivos tiene que estar unido por un edge.
- `status: draft` permite subir un patrón incompleto (warnings); `published` exige las 3 nubes y su Terraform.

## Implementation (por nube)

- `bindings`: para **cada** rol de tipo capability, `{ service, config?, notes?, equivalence?, from? }` o
  `{ gap }`.
  - `equivalence: partial` cuando el servicio cumple el rol pero no es un equivalente directo (otro alcance,
    otro modelo). Exige `notes` que expliquen la diferencia; el diagrama lo dibuja punteado con "≈".
  - `from.<nube>`: qué cambia para quien viene de esa nube ("Venís de Azure: …"). El sitio ya muestra qué
    servicio cumplía el rol allá; la nota curada suma el "pero". Solo hechos que ya respalda un gotcha.
- `gotchas`: la "letra chica". Campos obligatorios:
  - `severity`: `security | iam | networking | cost | reliability | operations`
  - `sources`: ≥ 1 URL https de un dominio oficial (lista en `OFFICIAL_SOURCE_HOSTS`)
  - `verified_at`: fecha ISO en que alguien leyó las fuentes y confirmó el texto
  - `roles` (opcional): roles del patrón a los que aplica; alimentan el contador por nodo y el panel del
    diagrama interactivo.
  - `exams` (opcional): códigos de certificación donde este conocimiento suma. Tienen que existir en
    `content/exams.yaml` y ser de la misma nube que la implementación.
- `cost`: `scales_to_zero` (`yes | no | partial`), `fixed_cost_drivers` y notas. Sin números todavía: los
  precios se calcularán en build (Fase 4) con región y fecha.

## Exámenes (`content/exams.yaml`)

Catálogo único de certificaciones: `code`, `provider`, `name` (oficial, sin traducir), `certification`,
`level`, `url` (study guide o página oficial) y, si corresponde, `retires_on` (último día en que se puede
rendir) y `replaced_by`. El estado **no se escribe a mano**: se deriva de `retires_on` contra la fecha del
build (`vigente` → `se retira` → `retirado`). Cuando un examen pasa a retirado, los gotchas que lo
referencian dan warning para re-etiquetarlos con el reemplazo. Google no publica códigos: usamos los
acrónimos de uso común (ACE, PCA, PCNE…).

## Validaciones cruzadas (`pnpm validate`)

| Regla | Nivel |
|---|---|
| `id` del patrón = nombre de carpeta | error |
| Roles y capabilities referenciadas existen; edges apuntan a roles existentes | error |
| Cada rol capability tiene binding en cada nube; los actores no | error |
| Patrón `published` tiene las 3 implementaciones y los 3 módulos con `main.tf`, `tests/` y versión pinneada | error |
| Gotchas únicos por nube; `verified_at` no futuro | error |
| `verified_at` > 180 días | warning (+ issue semanal) |
| Examen de un gotcha inexistente en el catálogo o de otra nube; `replaced_by` inexistente | error |
| Gotcha etiquetado con un examen ya retirado | warning |
| `roles` de un gotcha inexistentes o actores; recorrido con roles inexistentes o sin edge | error |
| `equivalence: partial` sin `notes`; `from` de la propia nube | error |
| Falta traducción al inglés | warning |

## Textos localizados

`{ es: "...", en: "..." }`. `es` es obligatorio; si falta `en`, la UI muestra el español y lo marca
"sin traducir".
