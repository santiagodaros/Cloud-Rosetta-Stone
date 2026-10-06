# Cloud Rosetta Stone

**Traducí arquitecturas entre Azure, AWS y GCP: dónde se rompe la analogía, con Terraform verificado.**

Las tablas de equivalencias dicen que S3 "es" Blob Storage. No te dicen que en Azure el prefijo de lifecycle
incluye el nombre del contenedor, que en GCP soft delete viene activo y te cobra 7 días extra por cada archivo
efímero, o que un `Deny` por `aws:SourceVpce` te deja afuera de tu propio bucket. Cloud Rosetta Stone compara
**patrones completos**, no servicios sueltos, y cada diferencia viene con su **fuente oficial y fecha de verificación**.

![Comparador: Ingesta privada de objetos con TTL, AWS vs Azure](docs/assets/comparador.png)

## Qué hay

- **Comparador lado a lado** (2 o 3 nubes) por patrón: diagrama con la misma topología, implementación por
  rol, modelo de costo, "letra chica" y Terraform.
- **Gotchas verificables:** severidad, fuente oficial obligatoria, `verified_at` y examen de certificación
  donde suma (AZ-104, AZ-700, SAA-C03, ACE…).
- **Terraform que compila y es seguro:** cada módulo pasa `fmt`, `validate`, `terraform test` (sin
  credenciales), `tflint` y `checkov` en cada PR.
- **Diccionario** de capabilities con huecos explícitos ("en AWS no hay un servicio único de data perimeter").
- **Datos abiertos:** `/api/v1/patterns.json` y `/api/v1/capabilities.json`.
- **Español primero**, inglés incluido. Sin cuentas, sin credenciales, sin trackers, $0.

## Estado

Fase 0 cerrada: fundaciones + 1 patrón de referencia en las 3 nubes. Ver el [plan](docs/PLAN.md) y el
[análisis que lo originó](docs/ANALISIS-END-TO-END.md).

| Patrón | Azure | AWS | GCP |
|---|---|---|---|
| Ingesta privada de objetos con expiración (TTL) | ✅ | ✅ | ✅ |
| Web API privada Zero Trust | Fase 1 | Fase 1 | Fase 1 |
| Worker asíncrono con escala a cero | Fase 1 | Fase 1 | Fase 1 |

## Desarrollo local

Requisitos: Node 22+, pnpm 10+. Terraform ≥ 1.7 solo si vas a tocar módulos.

```bash
pnpm install
pnpm dev          # http://localhost:4321
pnpm validate     # valida content/ (schema + referencias cruzadas)
pnpm test         # tests unitarios
pnpm build        # sitio estático en dist/
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
```

## Contribuir

La contribución más valiosa no es un patrón nuevo: es **re-verificar un gotcha** y actualizar su
`verified_at`. Ver [CONTRIBUTING.md](CONTRIBUTING.md).

## Licencia

Código y módulos de Terraform: [MIT](LICENSE). Contenido editorial y dataset: [CC BY-SA 4.0](LICENSE-CONTENT.md).
Proyecto independiente, sin afiliación con Microsoft, Amazon ni Google ([NOTICE](NOTICE.md)).
