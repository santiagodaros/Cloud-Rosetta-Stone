# Contribuir

Gracias por sumar. Este proyecto vale lo que vale la **exactitud** de su contenido, así que las reglas
están para proteger eso.

## Formas de contribuir (de más a menos impacto)

1. **Re-verificar un gotcha.** Abrí las fuentes, confirmá que el texto sigue siendo cierto, corregilo si
   cambió algo y actualizá `verified_at`. Hay un issue `freshness` que lista los vencidos.
2. **Reportar un gotcha incorrecto o desactualizado** (template "Gotcha desactualizado").
3. **Agregar un gotcha** a un patrón existente.
4. **Agregar una capability** al diccionario.
5. **Proponer o escribir un patrón nuevo** (abrí primero un issue con el template "Proponer patrón").
6. **Traducir** textos `es` → `en`.

¿Venís por Hacktoberfest? Mirá la [guía corta](docs/HACKTOBERFEST.md).

## Reglas editoriales

- **Un gotcha = hecho verificable + consecuencia + qué hacer.** Sin adjetivos ("increíble", "terrible").
- **Fuente oficial obligatoria.** Dominios aceptados: ver `OFFICIAL_SOURCE_HOSTS` en `src/lib/schema.ts`.
  Blogs, foros y videos sirven para descubrir un problema, no para respaldarlo.
- **`verified_at` = el día que leíste las fuentes**, no el día que escribiste el texto.
- **Sin ganador.** Si algo es más simple o barato en una nube, decí qué se paga en otro lado.
- **Comparar lo comparable:** mismo motor (PostgreSQL con PostgreSQL), mismo nivel de aislamiento de red.
- **Nunca** incluyas nombres de clientes, IDs de tenant/suscripción/cuenta/proyecto reales, IPs públicas o
  capturas con datos reales. Usá `example`, `contoso`, `123456789012`.
- Español rioplatense neutro y técnico; el inglés es bienvenido como traducción.

## Agregar o modificar un patrón

Arrancá con el scaffolder (crea todo en estado `draft`, con módulos de Terraform que ya validan):

```bash
pnpm new:pattern <slug> <capability> [<capability> ...]
```

Estructura resultante:

```
content/patterns/<slug>/
├── pattern.yaml            # roles + edges: la topología, UNA sola vez
├── azure.yaml aws.yaml gcp.yaml
└── terraform/<nube>/
    ├── versions.tf         # required_providers con versión pinneada (~> X.Y)
    ├── variables.tf        # con validation donde tenga sentido
    ├── main.tf             # comentá qué gotcha mitiga cada decisión: (gotcha: <id>)
    ├── outputs.tf
    └── tests/*.tftest.hcl  # mock_provider + command = plan + asserts de lo que el patrón promete
```

Requisitos para que un PR de Terraform se mergee:

- `terraform fmt -check`, `terraform validate` y `terraform test` en verde.
- `tflint` sin errores con `.tflint/<nube>.hcl`.
- `checkov` sin fallas. Si una regla no aplica, `#checkov:skip=ID:motivo` **dentro del recurso**, con un
  motivo que un reviewer pueda evaluar. "No aplica" no es un motivo.
- Sin secretos, sin backends remotos, sin `provider` con credenciales.
- Los tests no pueden requerir credenciales ni crear recursos.

## Flujo local

```bash
pnpm install
pnpm validate      # schema + referencias cruzadas; muestra errores por archivo
pnpm test
pnpm dev           # revisá cómo se ve en http://localhost:4321
```

## Checklist del PR

- [ ] `pnpm validate` sin errores
- [ ] Cada gotcha nuevo o modificado tiene fuente oficial y `verified_at` de hoy
- [ ] Si toqué Terraform: fmt, validate, test, tflint y checkov en verde
- [ ] Sin datos de clientes, tenants o cuentas reales
- [ ] Texto neutral (sin "ganador")

## Revisión

Cada nube tiene reviewers en `.github/CODEOWNERS`. Un cambio en `aws.yaml` lo revisa alguien con
experiencia real en AWS. Si querés ser reviewer de una nube, abrí un issue.
