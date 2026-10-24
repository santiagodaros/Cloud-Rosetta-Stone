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
- [ ] Script `lint` (única falta del arnés; `typecheck` ya existe como `pnpm check`).
- [ ] Revisar permisos de `ci.yml` (`ci.yml:9`) y fijar acciones por SHA (opcional).
- [ ] Respetar `Retry-After` en el 429 de `scripts/fetch-prices.ts` (hoy backoff fijo; riesgo bajo).
- [ ] Mantener un solo número de patrones/gotchas: hoy README, PLAN y la home pueden desfasarse. Generarlo desde `pnpm validate`.

### Congelado (no empezar)
- F4-04 Infracost, F4-06 deploy sandbox, F4-07 IA, F4-08 OCI, F4-20 votación.
