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
- `published` exige además al menos un gotcha con `verified_by` (revisión externa) en cada nube. Los patrones publicados antes de esta regla llevan `legacy_unreviewed: true` y solo dan warning; no se agrega a patrones nuevos.

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
  - `verified_by` (opcional): usuario de GitHub (sin `@`) de quien lo re-verificó además del mantenedor. Sin
    el campo, la UI muestra "sin revisor externo". El schema valida el formato, no que la persona tenga experiencia.
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

## Conceptos (`content/concepts/*.yaml`)

Estructura de cada nube, no servicios: jerarquía de recursos, límite de facturación, alcance de la red, zonas,
identidad de personas, tags/labels, identificadores. Por nube: `terms` (de mayor a menor alcance, cada uno con
link oficial) y `explanation`. Los `caveats` ("dónde se rompe la analogía") exigen `sources` oficiales, y el
concepto entero lleva `verified_at`.

## Mapa de recursos Terraform (`content/terraform-map.yaml`)

Qué recurso de `azurerm`, `aws` y `google` cumple el mismo papel. Cada entrada tiene `resources.{azure,aws,gcp}`
(tipos de recurso, o `recurso.bloque` cuando en una nube es un bloque), `match` (`one-to-one`, `partial`,
`gap`) y `notes` obligatorias si no es 1:1. CI baja los providers con las versiones del mapa, genera
`terraform providers schema -json` y falla si algún recurso o bloque no existe (`pnpm tf:map-check`).

## Precios de lista (`content/pricing.yaml` → `content/prices.json`)

`meters`: cada uno dice cómo encontrar **un** precio en la API pública de su nube (`azure.match` sobre la
Retail Prices API, `aws.match` sobre los atributos del Price List bulk, `gcp.description` en el Cloud Billing
Catalog) y su `unit` (`hour`, `month`, `gb-month`). Un meter de GCP lleva además `manual` (precio tomado del
SKU explorer oficial, con `verified_at` y `source`) porque la API de GCP pide key.

`floors.<patrón>.{azure,aws,gcp}`: lista de `{ meter, count }` con lo que se paga con cero tráfico y la
configuración por default del módulo. Lista vacía = sin costo fijo. Tiene que coincidir con
`cost.fixed_cost_drivers`: hay piso si y solo si hay drivers.

`content/prices.json` lo escribe `pnpm prices:fetch` (workflow semanal `prices.yml`, que abre un PR si algo
cambió). No se edita a mano: cada entrada guarda de qué SKU o meter salió (`ref`) y si vino de la API o es
manual (`source`). El job `prices` de CI falla si algún selector no resuelve a exactamente un precio.

## Matriz de decisión (`content/decisions/*.yaml`)

Una por capability: `requirements` (id + label) y `options`, cada una con `provider`, `name` (servicio + SKU o
modo), `meets.<requisito>` (`yes`, `no` o `{ value: partial, note }`; también se puede dar nota a yes/no),
`floor` (meters de `pricing.yaml`), `notes` y `sources` (mínimo una). Las tres nubes tienen que tener al
menos una opción.

## Validaciones cruzadas (`pnpm validate`)

| Regla | Nivel |
|---|---|
| `id` del patrón = nombre de carpeta | error |
| Roles y capabilities referenciadas existen; edges apuntan a roles existentes | error |
| Cada rol capability tiene binding en cada nube; los actores no | error |
| Patrón `published` tiene las 3 implementaciones y los 3 módulos con `main.tf`, `tests/` y versión pinneada | error |
| Patrón `published` sin ningún gotcha con `verified_by` en alguna nube | error (warning si lleva `legacy_unreviewed: true`) |
| Gotchas únicos por nube; `verified_at` no futuro | error |
| `verified_at` > 180 días | warning (+ issue semanal) |
| Examen de un gotcha inexistente en el catálogo o de otra nube; `replaced_by` inexistente | error |
| Gotcha etiquetado con un examen ya retirado | warning |
| `roles` de un gotcha inexistentes o actores; recorrido con roles inexistentes o sin edge | error |
| `equivalence: partial` sin `notes`; `from` de la propia nube | error |
| Mapa Terraform: prefijo de otra nube, `gap` sin nube vacía o nube vacía sin `gap`, `partial`/`gap` sin notas, capability o concepto inexistente | error |
| Recurso o bloque del mapa inexistente en el provider pinneado | error (job `terraform-map` de CI) |
| Precios: meter duplicado, sin selector ni `manual`, selector de otra nube; piso con meter inexistente o de otra nube; piso vacío con `fixed_cost_drivers` (o al revés) | error |
| Precios: meter sin entrada en `prices.json`, precio de más de 45 días | warning |
| Selector de precio que no resuelve a exactamente un precio | error (job `prices` de CI) |
| Decisión: capability inexistente, requisito sin evaluar o inexistente, opción o requisito duplicado, nube sin opciones | error |
| Falta traducción al inglés | warning |

## Textos localizados

`{ es: "...", en: "..." }`. `es` es obligatorio; si falta `en`, la UI muestra el español y lo marca
"sin traducir".
