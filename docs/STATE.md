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
- [x] Segunda verificación independiente de esas correcciones (2026-10-24): 29 gotchas releídos, 13 confirmados y 16 parciales (frases que quedaron más amplias que su fuente: títulos absolutos, comparaciones entre nubes sin respaldo, inferencias; una era mía: "token fresco cada vez" en `rds-iam-token-lifetime`). Se recortaron o se ajustaron a la fuente.
- [ ] Re-verificar de verdad (acción humana): `pnpm freshness --review` lista la cola por nube, los más severos primero. Al revisar uno, actualizar `verified_at` y sumar `verified_by`. Así las fechas dejan de ser todas el 2026-10-06.
- [x] Declarar en README, `/methodology` y CONTRIBUTING qué verifica el schema (hay fuente oficial) y qué no (que sea cierto).
- [ ] Al incorporar un revisor: descomentar su nube en `.github/CODEOWNERS`.

### 2. Patrones (meta: 12 a seis meses; hoy 5)
- [x] Borradores construidos en rama `feat/new-patterns` (2026-10-24): `app-secrets` (#16), `controlled-egress` (#17), `hub-and-spoke` (#15), 49 gotchas. Cada uno lo escribió un agente y lo verificó otro contra las fuentes (32 confirmados, 14 parciales, 2 dudosos, 1 no verificable); los hallazgos se corrigieron con cita textual o recorte.
- [x] Segunda tanda de borradores (2026-10-24): `preventive-guardrails`, `centralized-audit-logging` y `protected-origin-cdn` (42 gotchas), cada uno escrito por un agente y verificado por otro contra las fuentes oficiales: 38 confirmados, 4 parciales, 0 dudosos; también se revisaron las etiquetas de examen y los bindings. Los hallazgos se corrigieron con cita textual o recorte. Terraform validado localmente (fmt, validate, test, tflint, checkov), pisos de costo en `content/pricing.yaml` y filas en `content/terraform-map.yaml` cargados. Quedan como borrador: para publicarlos hace falta una revisión humana de cada nube (la regla está en el validador, PR #31).
- [x] Terraform validado localmente (2026-10-24) con las versiones del CI: `fmt`, `validate`, `test` (9 módulos nuevos), tflint 0.27.0 y checkov (432 pasan, 0 fallan, 69 skips con motivo en el código). Pisos de costo en `content/pricing.yaml` y filas en `content/terraform-map.yaml` cargados.
- [ ] Para publicar cada uno: CI verde en GitHub, revisión humana de su nube (ver `docs/REVISORES.md`) y recién ahí `status: published`.
- [x] Resueltos (2026-10-24): costo del firewall endpoint de GCP en hub-and-spoke (1.75 USD/h por endpoint, leído de la página oficial; `scales_to_zero: no`); `ip_protocol = "all"` de GCP en controlled-egress (la doc no lo respalda: se reemplazó por los 7 protocolos nombrados; el deny ya no cubre protocolos que solo se indican por número); skips de checkov `CKV2_AWS_63` y `CKV2_AWS_11` de hub-and-spoke AWS (ahora hay logging y flow logs opcionales; ojo: con el default `null` no se crean, checkov los da por satisfechos por presencia de los recursos).
- [ ] Abiertos: el NAT Gateway de Azure en controlled-egress usa el precio del SKU Standard como referencia (el módulo usa StandardV2 y la API de Retail Prices solo publica un cargo mensual "Log Enabled", no una tarifa por hora); `CKV_AZURE_216` apoyado en que la policy ya cubre threat intelligence.
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
- [x] Decidido: se queda Renovate (`renovate.json`) y se borró `.github/dependabot.yml`. Renovate cubre npm, acciones de GitHub, providers de Terraform y plugins de tflint. Falta instalar la app (ver `docs/MANTENEDOR-SETUP.md`, sección 6): hasta entonces no hay ningún bot de dependencias activo.
- [ ] El CI de GitHub no corre: la cuenta tiene un problema de facturación ("recent account payments have failed or your spending limit needs to be increased"). Hasta resolverlo, ninguna rama pasó CI real; todo se validó localmente con las versiones del CI.

### Congelado (no empezar)
- F4-04 Infracost, F4-06 deploy sandbox, F4-07 IA, F4-08 OCI, F4-20 votación.
