# Cloud Rosetta Stone — Plan de producto y ejecución

> Plan vivo. Se actualiza al cerrar cada fase. Base: [`ANALISIS-END-TO-END.md`](./ANALISIS-END-TO-END.md).
> Última actualización: 2026-10-06 (cierre de Fase 0).

---

## 1. Norte

**Misión:** que cualquier ingeniero que domina una nube pueda diseñar bien en otra, entendiendo
*dónde se rompe la analogía*, sin pagar nada y en su idioma.

**Posicionamiento (una línea):** _patrón de negocio → arquitectura equivalente en 3 nubes → por qué NO es
equivalente → Terraform verificado → piso de costo._ Las tablas 1:1 ya existen; esto no.

**Diferenciales que defendemos en cada decisión:**

| # | Diferencial | Cómo se garantiza (no opinión: mecanismo) |
|---|---|---|
| D1 | **Patrones, no servicios** | La unidad de contenido es `pattern.yaml` con topología abstracta compartida |
| D2 | **Cada claim con fuente oficial** | `SourceUrl` solo acepta dominios oficiales; `sources.min(1)`; lychee en CI |
| D3 | **Contenido fechado** | `verified_at` obligatorio; badge en UI; workflow semanal abre issue de frescura |
| D4 | **IaC que compila y es seguro** | fmt + validate + `terraform test` (mock) + tflint + checkov en cada PR |
| D5 | **Neutral** | Guía editorial "sin ganador"; CODEOWNERS por nube (ver §6) |
| D6 | **Español primero, bilingüe** | `Localized.es` obligatorio; `en` con fallback visible |
| D7 | **Abierto y reutilizable** | Código MIT, contenido CC BY-SA, dataset `/api/v1/*.json` |
| D8 | **$0 y sin credenciales** | Sitio 100% estático en GitHub Pages; nada se conecta a nubes |

---

## 2. Arquitectura (decidida en Fase 0)

```
content/ (YAML + .tf)  ──►  src/lib/schema.ts (Zod)  ──►  src/lib/content.ts (validación cruzada)
                                                             │
                     ┌───────────────────────────────────────┼─────────────────────────┐
                     ▼                                       ▼                         ▼
           pnpm validate (CI)                 Astro build (SSG, ELK → SVG)     /api/v1/*.json
                                                             │
                                                             ▼
                                                   GitHub Pages (estático)
```

Decisiones registradas en [`docs/adr/`](./adr/):
[0001 content-as-code](./adr/0001-content-as-code.md) ·
[0002 Astro estático](./adr/0002-astro-static-site.md) ·
[0003 diagramas en build time](./adr/0003-build-time-diagrams.md) ·
[0004 pipeline de calidad de IaC](./adr/0004-iac-quality-pipeline.md).

---

## 3. Fases

### Fase 0 — Fundaciones ✅ (cerrada 2026-10-06)

**Objetivo:** que agregar contenido sea seguro y repetible antes de escalar contenido.

| Entregable | Estado |
|---|---|
| Schema de contenido (Zod) + validación cruzada + validador CLI con anotaciones de GitHub | ✅ |
| Diccionario hub-and-spoke: 9 capabilities, incluido un `gap` real (data perimeter en AWS) | ✅ |
| Patrón de referencia real en 3 nubes: **Ingesta privada de objetos con TTL** (17 gotchas con fuente) | ✅ |
| 3 módulos de Terraform (azurerm 5.8, aws 6.67, google 8.6) con 14 `terraform test` sin credenciales | ✅ |
| Checkov: 0 fallas; cada skip justificado en el código | ✅ |
| Sitio: home, comparador (6 pares + vista de 3), diccionario, es/en, dark mode, mobile | ✅ |
| Diagramas SVG en build time con layout idéntico entre nubes | ✅ |
| Dataset abierto `/api/v1/patterns.json` y `/api/v1/capabilities.json` | ✅ |
| CI: contenido, typecheck, tests, build, matriz de Terraform, tflint, checkov, links | ✅ |
| Deploy a GitHub Pages + rebuild semanal; workflow de frescura; Renovate | ✅ |
| Docs: CONTRIBUTING, modelo de contenido, ADRs, licencias, templates de issue/PR | ✅ |

**Criterio de salida:** CI verde en `main` con 1 patrón real. → Pendiente de la primera corrida en GitHub
(ver §7, "Pendientes de Fase 0").

### Fase 1 — MVP de contenido (3–4 semanas)

**Objetivo:** suficiente profundidad para que el lanzamiento tenga sustancia y cubra las 3 nubes.

| ID | Tarea | Tamaño | Notas |
|---|---|---|---|
| F1-01 | Patrón **Web API privada Zero Trust** (ACA + PostgreSQL Flexible w/ Entra · ECS Fargate + RDS IAM auth · Cloud Run + Cloud SQL IAM auth) | L | Comparar PostgreSQL con PostgreSQL (no Azure SQL) |
| F1-02 | Patrón **Worker asíncrono con escala a cero** (ACA Jobs + Service Bus · Lambda/ECS + SQS · Cloud Run + Pub/Sub) | L | Gotchas: Premium para PE, at-least-once en las 3, ECS no escala a cero nativo |
| F1-03 | `pnpm new:pattern <slug>`: scaffolder con YAML + módulos + tests vacíos | S | Baja la barrera de contribución |
| F1-04 | OG image por comparación (satori en build) | M | Clave para LinkedIn: cada link tiene preview propio |
| F1-05 | Búsqueda estática (Pagefind) sobre patrones, capabilities y gotchas | S | |
| F1-06 | Diccionario a ~30 capabilities (red, identidad, datos, cómputo, observabilidad) | M | Prioridad: las que usan F1-01/02 |
| F1-07 | Deep links a gotchas (`#aws-sourcevpce-lockout`) con botón "copiar link" | S | Para citar en PRs/Slack |
| F1-08 | Página "Cómo verificamos" (metodología, fuentes aceptadas, frescura) | S | Credibilidad |
| F1-09 | Traducción EN completa de F1-01/02 | S | |
| F1-10 | Lighthouse ≥ 95 en performance/accesibilidad en CI (budget) | S | |

**Criterio de salida:** 3 patrones × 3 nubes publicados, todos los gotchas con fuente y < 90 días,
OG images funcionando, CI verde.

### Fase 2 — Lanzamiento (1 semana)

| ID | Tarea | Notas |
|---|---|---|
| F2-01 | Validar nombre: repo, dominio y handle libres (existe un "Cloud Rosetta" previo, ver análisis §2) | **Antes** del post de expectativa |
| F2-02 | Post LinkedIn Fase 1 (dolor + tesis) con screenshot del comparador | Copy en `ANALISIS-END-TO-END.md` §11 |
| F2-03 | Post Fase 2 (lanzamiento) + Show HN + r/AZURE, r/aws, r/googlecloud | Link en primer comentario |
| F2-04 | Post Fase 3 (letra chica) — **con el copy corregido** (Peek-Lock ≠ exactly-once) | |
| F2-05 | Serie semanal "Gotcha de la semana": cada post → deep link + OG image | Contenido recurrente sin costo extra |
| F2-06 | 10 issues `good first issue` listos ("verificar gotcha X", "traducir Y", "capability Z") | Para la ola de visitas del lanzamiento |

**Criterio de salida:** primer PR externo abierto.

### Fase 3 — Comunidad y aprendizaje (continuo, desde el lanzamiento)

| ID | Tarea | Tamaño |
|---|---|---|
| F3-01 | **Modo quiz** ("¿qué nube es esta arquitectura?" — el *blind mode* de isbetter.ai): oculta logos y nombres, el usuario adivina | M |
| F3-02 | Flashcards de gotchas filtradas por examen (AZ-104/305/700, SAA-C03, ACE/PCA) | M |
| F3-03 | Página por examen: "lo que tenés que saber de la otra nube si rendís X" | S |
| F3-04 | 5 patrones nuevos (≥ 2 de contribuidores): hub-and-spoke, OIDC CI/CD → nube, DNS privado híbrido, secretos, egress/NAT | L c/u |
| F3-05 | Reclutar CODEOWNERS de AWS y GCP (comunidades LATAM: AWS UG, GDG) | — |
| F3-06 | Hacktoberfest: etiquetar issues y publicar guía corta | S |

### Fase 4 — Plataforma (trimestre siguiente)

| ID | Tarea | Notas |
|---|---|---|
| F4-01 | **MCP server read-only** sobre el dataset: que Claude/Copilot citen gotchas verificados | Sirve el mismo JSON; $0 |
| F4-02 | `llms.txt` + dataset versionado (`schema_version`) | |
| F4-03 | **Pricing job** semanal: Azure Retail Prices API, AWS Price List, GCP Billing Catalog → "piso mensual" por patrón/región | Build time, nunca runtime |
| F4-04 | Alternativa: Infracost en CI sobre los módulos | Requiere API key gratuita como secret de CI |
| F4-05 | **Matriz de decisión**: requisitos (private-only, scale-to-zero, FIFO) → SKUs que lo cumplen + piso de costo | |
| F4-06 | (Opcional, con sponsor) deploy real nightly en cuentas sandbox vía OIDC + destroy | Fuera del sitio; solo CI |
| F4-07 | (Opcional) "Traducí mi Terraform" con IA, **solo BYOK client-side** y siempre con los gotchas curados al lado | Riesgo de alucinaciones vs. D2 |
| F4-08 | OCI como cuarta nube | Solo si hay CODEOWNER de OCI |
| F4-09 | **"Tu nube de origen"**: el usuario elige Azure/AWS/GCP una vez y el contenido se explica desde ahí ("venís de Azure: es como Private Endpoint, pero…") | Preferencia en `localStorage`, sin cuentas (D8). Requiere un campo opcional `from_<nube>` por binding |
| F4-10 | **"Qué cambió"**: changelog de gotchas creados, corregidos o re-verificados, con diff de texto, + feed RSS/Atom | Build time desde el historial de git y `verified_at`; es la excusa honesta para volver cada semana |
| F4-11 | **"Copiar como Markdown"** en cada gotcha y comparación (texto + fuente + `verified_at` + link) | Para pegar en PRs, ADRs y tickets; cada pegada es un link entrante (métrica §5) |
| F4-12 | **"Reportar desactualizado"** en cada gotcha → abre `stale-gotcha.yml` con `location` precargado | Los issue forms aceptan precarga por query param (`?template=…&location=…`); baja la fricción para contribuir |
| F4-13 | **Checklist de migración**: origen → destino → patrón = lista de gotchas a validar, exportable a Markdown/PDF | Uso directo en preventa y kick-off de migraciones; reutiliza los gotchas, sin contenido nuevo |
| F4-14 | **Generador de ADR** desde la comparación: decisión, alternativas descartadas, gotchas citados con fuente | Plantilla MADR; 100% client-side |
| F4-15 | **Mapa de recursos Terraform** `azurerm_*` ↔ `aws_*` ↔ `google_*`, curado, con marca "no es 1:1" | Nuevo tipo de contenido con schema y fuente obligatoria; es la alternativa verificada a F4-07 |
| F4-16 | **Diccionario de conceptos** (no servicios): jerarquía de recursos (tenant/MG/subscription/RG · org/OU/account · org/folder/project), regiones y zonas, modelo de identidad | Donde más se confunde quien salta de nube; mismo formato hub-and-spoke que capabilities |
| F4-17 | **Repetición espaciada** (Leitner) + "gotcha del día" sobre las flashcards de F3-02 | Progreso en `localStorage`; genera hábito diario sin login |
| F4-18 | **Widgets embebibles**: card de gotcha o comparación para blogs y Notion | Snippet `<iframe>`/HTML estático con link de vuelta; respeta CC BY-SA (atribución incluida) |
| F4-19 | **PWA offline** (service worker + manifest) | Estudiar desde el celular sin conexión; sitio ya es estático |
| F4-20 | **Votación del próximo patrón** con reacciones en GitHub Discussions, visible en el sitio | El ranking se lee en build time; la comunidad empuja el roadmap |
| F4-21 | **Decisión: medir retención** sin romper "sin trackers": Cloudflare Web Analytics (sin cookies, sin perfilado) o solo métricas proxy (suscriptores RSS, tráfico de GitHub, descargas del dataset) | Decide el mantenedor antes de F4-09; si se adopta, actualizar README y D8 |

F4-09 a F4-21 apuntan a **uso recurrente**: que el sitio entre en el trabajo diario (PRs, ADRs,
migraciones), en el estudio (repetición espaciada) y tenga novedades reales (changelog). Ritmo sugerido:
una feature chica por mes junto con el patrón mensual, en lugar de lanzar todo junto.

---

## 4. Guía editorial (resumen; completa en CONTRIBUTING)

1. **Un gotcha = un hecho verificable + su consecuencia + qué hacer.** Sin adjetivos de marketing.
2. **Sin ganador.** Si una nube es más barata en un punto, decí qué cuesta en otro.
3. **Fuente oficial obligatoria.** Blogs y foros sirven para descubrir, no para respaldar.
4. **Comparar lo comparable.** Mismo motor, mismo tier de red, mismo nivel de aislamiento.
5. **Nada de datos de clientes, tenants, suscripciones o cuentas reales** en ejemplos, issues ni capturas.

---

## 5. Métricas (revisión mensual)

| Métrica | Objetivo a 6 meses | Por qué |
|---|---|---|
| Contribuidores externos con PR mergeado | ≥ 10 | Señal de proyecto vivo |
| Gotchas con `verified_at` < 180 días | ≥ 90 % | D3 |
| Patrones en 3 nubes | ≥ 12 | Profundidad |
| Links entrantes desde docs/blogs/PRs de terceros | creciente | "Ser la referencia" |
| Estrellas | ~1k (benchmark: Cloud-Product-Mapping) | Vanity, pero sirve para distribución |

---

## 6. Gobernanza

- **CODEOWNERS por nube** (`.github/CODEOWNERS`): un reviewer con experiencia real por proveedor. Hasta
  tener AWS y GCP, el mantenedor revisa todo y lo declara en el README.
- **Licencias:** código MIT ([`LICENSE`](../LICENSE)); contenido CC BY-SA 4.0 ([`LICENSE-CONTENT.md`](../LICENSE-CONTENT.md)).
- **Marcas:** sin logos oficiales; solo nombres y colores genéricos ([`NOTICE.md`](../NOTICE.md)).

---

## 7. Pendientes de Fase 0 (requieren acción en GitHub)

| Pendiente | Quién | Cómo |
|---|---|---|
| Primera corrida de CI en GitHub | Mantenedor | Abrir PR de esta rama → revisar checks |
| Versiones de plugins de tflint | CI / Renovate | Se fijaron versiones conocidas sin poder verificar la última; si `tflint --init` falla, actualizar `.tflint/*.hcl`. Renovate las mantiene después |
| Habilitar GitHub Pages | Mantenedor | Settings → Pages → Source: **GitHub Actions** |
| Instalar la GitHub App de Renovate | Mantenedor | https://github.com/apps/renovate |
| Crear labels `freshness`, `good first issue`, `dependencies`, `terraform` | Mantenedor | El workflow de frescura usa `freshness` |
| Habilitar *private vulnerability reporting* | Mantenedor | Settings → Security (lo referencia SECURITY.md) |
| Habilitar Discussions | Mantenedor | Settings → General → Features (lo referencia el template de issues) |

---

## 8. Riesgos vivos

| Riesgo | Señal temprana | Mitigación |
|---|---|---|
| Contenido desactualizado | Issue de frescura crece | Issues `good first issue` de re-verificación; badge visible |
| Sesgo pro-Azure | Feedback de la comunidad AWS/GCP | CODEOWNERS por nube, guía "sin ganador" |
| Breaking changes de providers | PR de Renovate en rojo | Es el sistema funcionando: el PR rojo indica qué snippet actualizar |
| Bus factor = 1 | Un solo mergeador | Contenido en YAML simple + docs de contribución + co-maintainers en Fase 3 |
| Colisión de nombre | — | F2-01 antes de cualquier post |
