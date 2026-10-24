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
- [ ] Revisor por nube para AWS y GCP (F3-05, convocatoria en #18): difundir en AWS UG y GDG LATAM.
- [ ] Campo de quién verificó en cada gotcha (`verified_by`) y fechas escalonadas, no todas el 2026-10-06. Decidir si entra al schema.
- [ ] Re-verificación priorizada por severidad: los gotchas de mayor severidad primero (issues `good first issue`).
- [ ] Declarar en README y `/methodology` qué verifica el schema (hay fuente oficial) y qué no (que sea cierto).

### 2. Patrones (meta: 12 a seis meses; hoy 5)
- [ ] #15 hub-and-spoke, #16 secretos, #17 egress/NAT.
- [ ] Un patrón nuevo por mes, sin funciones nuevas en paralelo.

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
