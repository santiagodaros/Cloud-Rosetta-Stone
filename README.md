# Letra Chica

**La letra chica del multicloud: dónde se rompe la analogía entre Azure, AWS y GCP, con fuentes oficiales y Terraform verificado.**

_The fine print of multicloud — Spanish first, English included._

[![CI](https://github.com/santiagodaros/Cloud-Rosetta-Stone/actions/workflows/ci.yml/badge.svg)](https://github.com/santiagodaros/Cloud-Rosetta-Stone/actions/workflows/ci.yml)
[![Código: MIT](https://img.shields.io/badge/c%C3%B3digo-MIT-blue)](LICENSE)
[![Contenido: CC BY-SA 4.0](https://img.shields.io/badge/contenido-CC%20BY--SA%204.0-lightgrey)](LICENSE-CONTENT.md)

**Sitio:** https://santiagodaros.github.io/Cloud-Rosetta-Stone/ · **Datos abiertos:** [`/api/v1/patterns.json`](https://santiagodaros.github.io/Cloud-Rosetta-Stone/api/v1/patterns.json)

Las tablas de equivalencias dicen que S3 "es" Blob Storage. No te dicen que en Azure el prefijo de lifecycle
incluye el nombre del contenedor, que en GCP soft delete viene activo y te cobra 7 días extra por cada archivo
efímero, o que un `Deny` por `aws:SourceVpce` te deja afuera de tu propio bucket. Letra Chica compara
**patrones completos**, no servicios sueltos, y cada diferencia viene con su **fuente oficial y fecha de verificación**.

![Comparador: Ingesta privada de objetos con TTL, AWS vs Azure](docs/assets/comparador.png)

## Qué hay

- **Comparador lado a lado** (2 o 3 nubes) por patrón: diagrama con la misma topología, implementación por
  rol, modelo de costo, "letra chica" y Terraform.
- **Gotchas verificables:** severidad, fuente oficial obligatoria, `verified_at` y examen de certificación
  donde suma (AZ-104, AZ-700, SAA-C03, ACE…).
- **Por examen:** cada certificación tiene su página con los gotchas que aplican y su estado (vigente, se
  retira, retirado → reemplazo), derivado de la fecha de retiro oficial.
- **Práctica:** modo a ciegas ("¿de qué nube es este gotcha?", con los nombres de producto tapados) y
  flashcards filtrables por examen.
- **Terraform que compila y es seguro:** cada módulo pasa `fmt`, `validate`, `terraform test` (sin
  credenciales), `tflint` y `checkov` en cada PR.
- **Diccionario** de capabilities con huecos explícitos ("en AWS no hay un servicio único de data perimeter").
- **Datos abiertos:** `/api/v1/patterns.json`, `/api/v1/capabilities.json` y `/api/v1/exams.json`.
- **Para compartir:** cada comparación tiene su imagen OG y cada gotcha un deep link.
- **Búsqueda** estática (Pagefind) en español e inglés.
- **Español primero**, inglés incluido. Sin cuentas, sin credenciales, sin trackers, $0.

## Estado

Fase 1 cerrada: 3 patrones en las 3 nubes, 45 gotchas con fuente oficial, 26 capabilities. Ver el
[plan](docs/PLAN.md) y el [análisis que lo originó](docs/ANALISIS-END-TO-END.md).

| Patrón | Azure | AWS | GCP |
|---|---|---|---|
| Ingesta privada de objetos con expiración (TTL) | Blob + lifecycle + Private Endpoint | S3 + lifecycle + Gateway Endpoint | GCS + lifecycle + PGA |
| Web API privada Zero Trust (PostgreSQL sin contraseñas) | ACA interno + PG Flexible (Entra) | ECS Fargate + ALB interno + RDS IAM | Cloud Run internal + Cloud SQL IAM |
| Worker asíncrono con escala a cero y dead-letter | ACA Jobs + Service Bus | Lambda + SQS | Cloud Run + Pub/Sub push |

## Desarrollo local

Requisitos: Node 22+, pnpm 10+. Terraform ≥ 1.7 solo si vas a tocar módulos.

```bash
pnpm install
pnpm dev          # http://localhost:4321
pnpm validate     # valida content/ (schema + referencias cruzadas)
pnpm test         # tests unitarios
pnpm build        # sitio estático en dist/ + índice de búsqueda
pnpm new:pattern mi-patron message-queue object-storage   # esqueleto de un patrón nuevo
```

Probar un módulo de Terraform sin credenciales:

```bash
cd content/patterns/object-storage-ttl/terraform/aws
terraform init -backend=false && terraform validate && terraform test
```

## Estructura

```
content/            ← el producto: patrones, capabilities, Terraform (PRs acá)
src/lib/schema.ts   ← schema del contenido (fuente de verdad)
src/lib/content.ts  ← carga + validación cruzada (la usan CI y el build)
src/lib/diagram.ts  ← layout ELK en build time → SVG
src/pages/          ← sitio Astro (es/en)
scripts/            ← validate, freshness report, matriz de Terraform para CI
docs/               ← plan, modelo de contenido, ADRs
docs/launch/        ← kit de lanzamiento (posts, Show HN, calendario)
```

## Contribuir

La contribución más valiosa no es un patrón nuevo: es **re-verificar un gotcha** y actualizar su
`verified_at`. Ver [CONTRIBUTING.md](CONTRIBUTING.md) y los issues
[`good first issue`](https://github.com/santiagodaros/Cloud-Rosetta-Stone/issues?q=is%3Aopen+label%3A%22good+first+issue%22).

## Licencia

Código y módulos de Terraform: [MIT](LICENSE). Contenido editorial y dataset: [CC BY-SA 4.0](LICENSE-CONTENT.md).
Proyecto independiente, sin afiliación con Microsoft, Amazon ni Google ([NOTICE](NOTICE.md)).
