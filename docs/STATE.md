# STATE

Estado vivo del proyecto. El hook rehydrate lo reinyecta tras /compact.

## Decisiones
- 2026-10-24: se frena la Fase 4 (no más funciones nuevas). El valor está en el contenido verificado, no en la plataforma.
- Orden de trabajo: confianza del contenido → cerrar patrones abiertos → pendientes de la maintainer.

## Hecho
- 2026-10-24: init de dev-flow (`chore/dev-flow-init`), endurecimiento de `set:html`, key de GCP en header y dependabot (`fix/review-hardening`).
- 2026-10-24: README alineado (5 patrones) y notas de typecheck corregidas (`pnpm check` ya existe y el CI lo corre).

## Pendiente (plan, en orden)

### 1. Confianza del contenido (D2/D3) — prioridad
- [ ] Revisor por nube para AWS y GCP (F3-05, convocatoria en #18): difundir en AWS UG y GDG LATAM. Ya existe el issue "Quiero revisar una nube" (`become-reviewer.yml`); falta publicarlo y difundirlo.
- [x] Campo `verified_by` opcional en el schema, badge en la tarjeta ("revisado por @x" / "sin revisor externo"), dataset y MCP. Los 74 gotchas actuales quedan sin el campo: no se afirma una revisión que no pasó.
- [x] Pre-verificación automática de los 74 gotchas contra sus fuentes (2026-10-24): `docs/PRE-VERIFICACION.md`. 44 confirmados, 28 parciales, 1 dudoso (`rds-iam-connection-rate`, AWS), 1 no verificable. No es una revisión: no cambió `verified_at` ni `verified_by`.
- [x] Workflow semanal con segundo issue "Cola de revisión por nube" y convocatoria de revisores en `docs/launch/convocatoria-revisores.md`.
- [x] Resuelto el dudoso (`rds-iam-connection-rate` → reescrito como `rds-iam-token-lifetime`, sin el límite de 200 conexiones/s que ya no está en la doc de AWS) y el no verificable (`vpc-plus-two-not-from-onprem`: fuente corregida a la página de Route 53 que sí lo dice). `verified_at` sigue en 2026-10-06 hasta que una persona lea las fuentes.
- [x] Resueltos los 28 parciales (11 de `iam`/`security` y 17 del resto): con fuente textual o recortando lo que no se pudo respaldar. Los recortes sacan lo no comprobado, no necesariamente lo falso: un revisor con experiencia puede reponer frases con su fuente.
- [ ] Releer el diff de esas 28 correcciones con ojos de revisor (`git log -p -- content`) antes de dar los gotchas por verificados.
- [ ] Re-verificar de verdad (acción humana): `pnpm freshness --review` lista la cola por nube, los más severos primero. Al revisar uno, actualizar `verified_at` y sumar `verified_by`. Así las fechas dejan de ser todas el 2026-10-06.
- [x] Declarar en README, `/methodology` y CONTRIBUTING qué verifica el schema (hay fuente oficial) y qué no (que sea cierto).
- [ ] Al incorporar un revisor: descomentar su nube en `.github/CODEOWNERS`.

### 2. Patrones (meta: 12 a seis meses; hoy 5)
- [x] Borradores construidos en rama `feat/new-patterns` (2026-10-24): `app-secrets` (#16), `controlled-egress` (#17), `hub-and-spoke` (#15), 49 gotchas. Cada uno lo escribió un agente y lo verificó otro contra las fuentes (32 confirmados, 14 parciales, 2 dudosos, 1 no verificable); los hallazgos se corrigieron con cita textual o recorte.
- [x] Terraform validado localmente (2026-10-24) con las versiones del CI: `fmt`, `validate`, `test` (9 módulos nuevos), tflint 0.27.0 y checkov (432 pasan, 0 fallan, 69 skips con motivo en el código). Pisos de costo en `content/pricing.yaml` y filas en `content/terraform-map.yaml` cargados.
- [ ] Para publicar cada uno: CI verde en GitHub, revisión humana de su nube (ver `docs/REVISORES.md`) y recién ahí `status: published`.
- [ ] Abiertos: `scales_to_zero: partial` provisional en GCP de hub-and-spoke (sin precio verificado del firewall endpoint); NAT Gateway de Azure en controlled-egress usa el precio del SKU Standard como referencia (el módulo usa StandardV2, que la API de precios no publica); `ip_protocol = "all"` en GCP de controlled-egress no está confirmado contra la API de GCP; skips de checkov por alcance (`CKV2_AWS_63`, `CKV2_AWS_11`) y `CKV_AZURE_216` apoyado en la policy.
- [ ] #15 hub-and-spoke, #16 secretos, #17 egress/NAT.
- [ ] Un patrón nuevo por mes, sin funciones nuevas en paralelo.

> Pasos concretos de las secciones 3 y 4 (comandos `gh`, qué habilita cada uno y cómo comprobarlo): `docs/MANTENEDOR-SETUP.md`.

### 3. Precios
- [ ] Crear secret `GCP_BILLING_API_KEY` para que los 7 meters de GCP salgan de la API (hoy manuales del 2026-10-06).
- [ ] Probar `prices.yml` a mano una vez: el cambio de key a header `x-goog-api-key` no se probó con key real.
- [ ] Habilitar "Allow GitHub Actions to create and approve pull requests".

### 4. Pendientes de la maintainer (Settings de GitHub / Vercel)
- [ ] Env `VERCEL_DEEP_CLONE=true` y secret `VERCEL_DEPLOY_HOOK_URL` (rebuild semanal).
- [ ] Topic `hacktoberfest` en el repo.
- [ ] Discussions (lo referencia el template de issues y F4-20).
- [ ] Private vulnerability reporting (lo referencia SECURITY.md).
- [ ] Labels `freshness`, `good first issue`, `dependencies`, `terraform`.
- [ ] Decidir F4-21 (medir retención vs. "sin trackers"); si se adopta, actualizar README y D8.

### 5. Higiene técnica
- [x] Script `lint` (ESLint 9, flat config) en `package.json`, `verify` y el CI. Encontró un bug real en el service worker (regex dentro de un template literal que perdía la barra).
- [x] Acciones de GitHub fijadas por SHA (`@sha # tag`) y permisos revisados: ya estaban al mínimo. Una interpolación de `${{ }}` en un `run:` pasó a `env:`.
- [x] `Retry-After` respetado en el 429/503 de `scripts/fetch-prices.ts` (tope 60 s).
- [x] Test que compara los conteos del README con el contenido (`tests/readme-counts.test.ts`).
- [ ] Decidir entre Renovate (`renovate.json`) y Dependabot (`.github/dependabot.yml`): hoy coexisten y pueden duplicar PRs. Ningún bot abrió PRs todavía, así que parece que Renovate no está instalado.
- [ ] El CI de GitHub no corre: la cuenta tiene un problema de facturación ("recent account payments have failed or your spending limit needs to be increased"). Hasta resolverlo, ninguna rama pasó CI real; todo se validó localmente con las versiones del CI.

### Congelado (no empezar)
- F4-04 Infracost, F4-06 deploy sandbox, F4-07 IA, F4-08 OCI, F4-20 votación.
