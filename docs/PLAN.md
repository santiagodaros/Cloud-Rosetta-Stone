# Letra Chica — Plan de producto y ejecución

> Plan vivo. Se actualiza al cerrar cada fase. Base: [`ANALISIS-END-TO-END.md`](./ANALISIS-END-TO-END.md).
> Última actualización: 2026-10-06 (cierre de Fase 1).

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

### Fase 1 — MVP de contenido ✅ (cerrada 2026-10-06)

**Objetivo:** suficiente profundidad para que el lanzamiento tenga sustancia y cubra las 3 nubes.

| ID | Tarea | Estado | Resultado |
|---|---|---|---|
| F1-01 | Patrón **Web API privada Zero Trust** | ✅ | ACA interno + PG Flexible solo Entra · ECS Fargate + ALB interno + RDS IAM auth · Cloud Run internal + Cloud SQL IAM. 16 gotchas, 14 tests |
| F1-02 | Patrón **Worker asíncrono con escala a cero** | ✅ | ACA Jobs + Service Bus (KEDA con identidad) · Lambda + SQS · Cloud Run + Pub/Sub push. 12 gotchas, 13 tests |
| F1-03 | `pnpm new:pattern <slug> [capability...]` | ✅ | Genera YAML draft + 3 módulos con tests que ya validan |
| F1-04 | OG image por comparación | ✅ | satori + resvg en build: 42 imágenes (3 patrones × 7 vistas × 2 idiomas) + home |
| F1-05 | Búsqueda estática | ✅ | Pagefind, índice por idioma; indexa la vista de 3 nubes, diccionario y metodología (sin HCL ni badges) |
| F1-06 | Diccionario | ✅ | 26 capabilities (antes 9), categorías nuevas `governance` y `observability` |
| F1-07 | Deep links a gotchas | ✅ | Botón 🔗 que copia `…/#<nube>-<gotcha>` |
| F1-08 | Página "Cómo verificamos" | ✅ | Fuentes aceptadas (desde el schema), frescura, checks de CI, limitaciones |
| F1-09 | Traducción EN | ✅ | Todo el contenido nuevo es bilingüe (0 warnings de traducción) |
| F1-10 | Budget de Lighthouse en CI | ✅ | ≥ 0.9 perf / ≥ 0.95 a11y; hoy 100 en las 4 categorías y 4 páginas |

**Criterio de salida:** 3 patrones × 3 nubes publicados, todos los gotchas con fuente y < 90 días, OG images
funcionando, CI verde. → 45 gotchas verificados el 2026-10-06; CI pendiente de la corrida del PR.

**Lo que encontró el pipeline en esta fase** (el valor de validar de verdad):
- azurerm 5 cambió `azurerm_private_dns_a_record` (ahora `private_dns_zone_id`); `validate` lo detectó.
- Lighthouse marcó contraste insuficiente en 5 colores de severidad y en los chips de AWS/GCP; se corrigió la
  paleta clara.
- checkov exige PostgreSQL 18 en Cloud SQL; se mantuvo 17 en las 3 nubes con el skip justificado.

### Fase 2 — Lanzamiento (preparada 2026-10-06)

Kit completo en [`docs/launch/`](./launch/). Lo que queda son acciones del mantenedor (publicar, configurar
el repo); el checklist está en [`docs/launch/README.md`](./launch/README.md).

| ID | Tarea | Estado | Resultado |
|---|---|---|---|
| F2-01 | Validar nombre | ✅ | Renombrado a **Letra Chica**: "Cloud Rosetta" colisiona con dos repos de GitHub (uno con el mismo concepto) y la marca "Rosetta Stone". Dominio: a verificar por el mantenedor |
| F2-02 | Post de expectativa | ✅ borrador | 2 variantes en `launch/linkedin.md` |
| F2-03 | Lanzamiento: LinkedIn, Show HN, Reddit | ✅ borrador | `launch/linkedin.md`, `launch/show-hn-y-reddit.md` |
| F2-04 | Post de letra chica con copy corregido | ✅ borrador | Peek-Lock = at-least-once; 2 variantes |
| F2-05 | Serie "Gotcha de la semana" | ✅ | 12 semanas generadas desde el contenido con `pnpm launch:weekly` |
| F2-06 | 10 `good first issue` | ✅ | Re-verificación, traducción y capabilities |

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
| Primera corrida de CI en GitHub | Mantenedor | ✅ Verde en PR #1 |
| Versiones de plugins de tflint | CI / Renovate | ✅ Pasaron en la primera corrida; Renovate las mantiene |
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
