# Cloud Rosetta Stone — Análisis end-to-end

> **Nota (2026-10-06):** el proyecto se renombró a **Letra Chica** en la Fase 2 por colisión de nombre con otros proyectos "Cloud Rosetta" y por la marca "Rosetta Stone". Este documento se conserva como registro del análisis original.

> Revisión crítica del spec original, landscape competitivo y propuesta para que el proyecto sea
> una herramienta open source de referencia para democratizar el conocimiento multicloud.
> Fecha de análisis: 2026-10-06.

---

## 0. TL;DR

1. **La idea es buena, pero no es única.** Ya existe un "Cloud Rosetta" (HTML único, explica dónde se
   rompe la analogía y linkea el recurso de Terraform de cada nube). La diferencia tiene que estar en
   **patrones completos + contenido verificado y con fuentes + español + datos abiertos (API/MCP)**,
   no en la tabla de equivalencias.
2. **isbetter.ai no compara nubes**: es una arena de modelos de IA (midudev). Lo que hay que copiar
   no es el dominio sino el *formato*: side-by-side, links compartibles, blind mode, BYOK, stack edge barato.
3. **Sacaría Supabase del MVP.** El contenido es read-only y versionable: va en el repo como YAML/MDX
   validado con schema, y se compila a un sitio estático. Supabase Free además **pausa el proyecto tras
   7 días sin actividad**, lo que choca con el guardrail de "$0 y siempre arriba".
4. **El spec tiene errores técnicos** que, publicados, dañarían justo la credibilidad que el proyecto
   quiere construir (ver §3.3). El más grave: Peek-Lock **no** da exactly-once.
5. **El moat real es la calidad del contenido**: cada gotcha con fuente oficial, fecha de verificación,
   y cada snippet de Terraform pasando `validate` + `tflint` + `checkov` en CI. Sin eso es otro blog.

---

## 1. Qué es isbetter.ai y qué tomar de ahí

| Aspecto | isbetter.ai | Qué transferir a Cloud Rosetta |
|---|---|---|
| Propósito | Misma prompt contra hasta 6 modelos, respuestas en streaming lado a lado | Mismo **patrón de negocio** contra 2–3 nubes, lado a lado |
| Vistas | Raw output / código extraído / preview sandboxed | Diagrama / gotchas / Terraform / costos (tabs por columna) |
| Blind mode | Oculta y mezcla identidades para juzgar sin sesgo | **Modo quiz**: "¿qué nube es esta arquitectura?" → aprendizaje activo |
| Shareable | Battles publicables por link | URL canónica por comparación (`/p/private-api/azure-vs-aws`) + OG image para LinkedIn |
| Privacidad | BYOK, keys en `localStorage`, nunca tocan su server | Mantener "cero credenciales"; si algún día hay IA, BYOK client-side |
| Stack | Astro + Cloudflare Workers + Tailwind 4 + D1 + Vitest | Astro (content-first) + hosting estático gratuito |
| Licencia | FSL-1.1-MIT (pasa a MIT a los 2 años) | Código MIT + **contenido CC BY-SA 4.0** (ver §7) |

Lección clave: isbetter.ai se viraliza porque **cada uso genera un artefacto compartible**. Cloud Rosetta
tiene que lograr lo mismo: que cada comparación sea un link con preview atractivo que alguien pegue
en un PR, un Slack o un post.

---

## 2. Landscape competitivo

| Herramienta | Tipo | Fortaleza | Hueco que deja |
|---|---|---|---|
| [Google Cloud – AWS/Azure service comparison](https://docs.cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison) | Tabla oficial filtrable | Autoridad, cobertura | 1:1 por servicio, sin diferencias de IAM/red, sesgo GCP |
| Microsoft – "AWS to Azure services comparison" / "Azure for AWS/GCP professionals" | Docs oficiales | Profundidad en Azure | Sesgo Azure, sin IaC comparado lado a lado |
| [AWS Prescriptive Guidance Patterns](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/welcome.html) | Catálogo de patrones | Paso a paso + código | Solo AWS, orientado a migrar *hacia* AWS |
| [Datadog Provider Services Map](https://datadoghq.com/providerservicesmap) | Tabla interactiva | Simple y rápida | 1:1, sin contexto |
| [milanm/Cloud-Product-Mapping](https://fr.github.com/milanm/Cloud-Product-Mapping) | Repo markdown (~900★) | Comunidad, incluye OCI | Lista de links, sin patrones ni gotchas |
| [CloudToolStack](https://cloudtoolstack.com/multi-cloud) | Tools client-side gratis | Contexto educativo, pricing, filtros | Por servicio/categoría, no por arquitectura; no open source |
| [Holori Compare](https://calculator.holori.com/compare) | Calculadora de costos | Pricing multi-proveedor | Comercial, foco en costos |
| "Cloud Rosetta" ([dev.to, Shane Law](https://dev.to/shane_law/the-cloud-comparison-chart-lied-to-you-a-little-39o9)) | HTML único offline | **Mismo pitch**: dónde se rompe la analogía + recurso Terraform | Concepto a concepto, no patrones completos; sin diagramas/costos |
| [Infracost](https://infracost.io/docs) | CLI de costos de Terraform | Estimación real desde HCL | No compara nubes; es input, no competidor |

**Conclusión de posicionamiento:** nadie hace bien la combinación
*patrón de negocio → arquitectura equivalente en 3 nubes → por qué NO es equivalente → IaC verificado → piso de costo*.
Ese es el nicho. Y nadie lo hace en **español**.

**Naming:** "Cloud Rosetta" ya está tomado conceptualmente. Recomiendo o bien diferenciar el nombre
(p. ej. *Rosetta Patterns*, *CloudBridge*, *Equivalente*) o mantener "Cloud Rosetta Stone" pero
asegurarse de que el repo, el dominio y el handle estén libres antes del post de Fase 1.

---

## 3. Diagnóstico del spec

### 3.1. Lo que está bien

- **Unidad de análisis = patrón, no servicio.** Es la decisión correcta y el diferencial.
- Guardrails "cero ejecución / cero credenciales": bajan el riesgo legal y de seguridad a casi cero.
- Foco en IAM, networking privado y costos ocultos: ahí está el dolor real de producción.
- Plan editorial atado al producto (cada post = un patrón).

### 3.2. Decisiones de arquitectura que cambiaría

| Spec | Problema | Propuesta |
|---|---|---|
| Supabase como fuente de datos | Contenido estático en una DB: contribuciones vía SQL en vez de PR, sin review/diff, y el Free tier **pausa el proyecto a los 7 días sin actividad** | **Content-as-code**: YAML/MDX en `content/`, schema Zod/JSON Schema, build estático. PR = contribución revisable |
| ISR para proteger cuotas | Resuelve un problema que no existiría sin DB | SSG puro; cero cuotas que cuidar |
| Next.js 15 | Next 16.x es la línea actual (16.3, con 15.5 en maintenance LTS). Para un sitio de contenido, Next agrega complejidad de server | **Astro** (content collections con Zod nativo, islas React para React Flow, Shiki incluido). Next 16 con `output: 'export'` es alternativa válida si querés practicar Next |
| Vercel Hobby | Hobby es **solo uso no comercial**; si mañana hay sponsor o se asocia a una empresa, hay que pasar a Pro | Cloudflare Pages o GitHub Pages (estático, bandwidth generoso, $0) |
| `flow_diagram_nodes` con coordenadas en JSONB por nube | Cada contribuidor dibuja a mano; diagramas inconsistentes | Definir la **topología una vez** con roles abstractos y mapear rol → servicio por nube; layout automático (ELK/dagre) |
| Tabla `service_mappings` par a par | Explosión combinatoria (3 nubes = 6 direcciones, y con OCI 12) | Modelo **hub-and-spoke**: `capability` canónica → implementación por proveedor |
| MVP "AWS, Azure y GCP" pero los 3 patrones solo cubren Azure/AWS | Promesa incumplida en el post de lanzamiento | Incluir GCP desde el día 1 o ajustar el mensaje a "Azure ↔ AWS (GCP en camino)" |

### 3.3. Errores técnicos en el contenido (corregir antes de publicar)

1. **"Azure Service Bus opera con Peek-Lock para asegurar procesamiento exactamente una vez" — incorrecto.**
   Peek-Lock da **at-least-once** (si el consumer cae antes de `complete`, el lock expira y el mensaje se
   reentrega). Es conceptualmente lo mismo que el *visibility timeout* de SQS; no es un diferencial.
   La duplicate detection de Service Bus deduplica **envíos** dentro de una ventana, no reemplaza
   consumidores idempotentes. Si querés un diferencial real: SQS FIFO tiene *exactly-once processing*
   con deduplicación de 5 minutos; Service Bus tiene sessions (FIFO por clave), DLQ nativa con
   `MaxDeliveryCount` y transacciones. Este error está en el copy de la Fase 3 de LinkedIn.
2. **"VPC Endpoint para SQS accesible en cualquier arquitectura"** — correcto en el fondo, pero no es gratis:
   un interface endpoint cobra por hora **por AZ** + por GB procesado. La comparación honesta es
   "decenas de USD/mes (3 AZ) vs. un SKU Premium de Service Bus que arranca en cientos de USD/mes por MU".
   El claim de Service Bus Premium para Private Endpoints sí es correcto (también lo exigen VNet rules y CMK).
3. **`DeleteAfterDays` no existe.** En la policy de lifecycle de Blob es
   `actions.baseBlob.delete.daysAfterModificationGreaterThan`; en `azurerm` es
   `delete_after_days_since_modification_greater_than` dentro de `azurerm_storage_management_policy`.
   Además: con soft delete habilitado, lifecycle deja el blob en estado soft-deleted (gotcha real para "TTL").
4. **Patrón 1 compara Azure SQL contra RDS PostgreSQL** — no es apples-to-apples. El equivalente es
   **Azure Database for PostgreSQL Flexible Server** con autenticación Entra ID (o comparar contra RDS for SQL Server).
   Y el gotcha real de IAM DB auth en RDS: el token dura 15 minutos y AWS recomienda no superar ~200
   conexiones nuevas/seg con IAM auth → hay que usar pooling o RDS Proxy.
5. **"Bloqueo de Public Access y deshabilitación de ACLs en S3" como gotcha** — desde abril 2023 son
   **default** en buckets nuevos. El gotcha vigente es otro: restringir por `aws:SourceVpce` en la bucket policy
   y no romper el acceso de la consola/CI al hacerlo.
6. **`shared_access_key_enabled = false` en Terraform** rompe operaciones de data plane del provider si no
   seteás `storage_use_azuread = true` en el bloque `provider "azurerm"`. Es *exactamente* el tipo de
   gotcha que la herramienta debería mostrar.
7. **"ECS Fargate escala a cero"** — se puede (`min_capacity = 0` en Application Auto Scaling + step
   scaling sobre `ApproximateNumberOfMessagesVisible`), pero no es nativo como KEDA en Container Apps Jobs,
   y target tracking con 0 tareas es engañoso. Para el equivalente "escala a cero" honesto en AWS, comparar
   también contra Lambda + SQS event source mapping.

Lección de producto: **si el spec del autor tiene 7 imprecisiones, el contenido de contribuidores tendrá más.**
Por eso §5 (pipeline de calidad) no es opcional.

---

## 4. Arquitectura recomendada

```
content/                      ← fuente de verdad (PRs de la comunidad)
├── capabilities/*.yaml       ← "queue", "private-connectivity", "workload-identity"...
├── patterns/<slug>/
│   ├── pattern.yaml          ← topología abstracta (roles + edges) + problema
│   ├── azure.yaml            ← rol → servicio, gotchas, costos, fuentes
│   ├── aws.yaml
│   ├── gcp.yaml
│   └── terraform/{azure,aws,gcp}/main.tf   ← código real, testeado
└── i18n/{es,en}/...

        │  build (GitHub Actions)
        ▼
┌───────────────────────────────────────────────┐
│ validate schema → tf fmt/validate/tflint →     │
│ checkov/trivy → terraform test (mock provider) │
│ → lychee (links) → precios (APIs públicas) →   │
│ Astro build → OG images (satori) → Pagefind    │
└───────────────────────────────────────────────┘
        │
        ▼
Sitio estático (CF Pages / GH Pages)  +  /api/v1/*.json (dataset abierto)
                                      +  MCP server read-only sobre el mismo JSON
```

### 4.1. Esquema de contenido (ejemplo)

```yaml
# content/patterns/async-worker/pattern.yaml
id: async-worker
category: async-event
title: { es: "Worker asíncrono desacoplado", en: "Decoupled async worker" }
problem: { es: "Procesar mensajes de una cola con escala a cero en reposo..." }
roles:
  - { id: producer,  kind: client }
  - { id: queue,     kind: capability, capability: message-queue }
  - { id: worker,    kind: capability, capability: event-driven-compute }
  - { id: storage,   kind: capability, capability: object-storage }
  - { id: identity,  kind: capability, capability: workload-identity }
edges:
  - [producer, queue, "send"]
  - [queue, worker, "trigger / pull"]
  - [worker, storage, "write"]
```

```yaml
# content/patterns/async-worker/azure.yaml
provider: azure
bindings:
  queue:    { service: "Azure Service Bus (Standard | Premium)" }
  worker:   { service: "Azure Container Apps Jobs (event-driven, KEDA)" }
  storage:  { service: "Azure Blob Storage" }
  identity: { service: "User-assigned Managed Identity" }
gotchas:
  - id: sb-private-endpoint-premium
    severity: cost          # cost | security | networking | iam | reliability
    text: { es: "Private Endpoint, VNet rules y CMK en Service Bus exigen tier Premium." }
    sources:
      - https://learn.microsoft.com/azure/service-bus-messaging/private-link-service
    verified_at: 2026-10-06
    exams: [AZ-305, AZ-700]
cost:
  floor_monthly_usd: { value: null, computed_by: pricing-job, region: eastus }
  scales_to_zero: partial   # yes | no | partial
```

Ventajas: diagramas consistentes entre nubes (misma topología), comparación N-a-N gratis,
y el contenido se puede consumir como dataset.

### 4.2. Costos sin ejecutar nada en la nube

- **Build-time**, no runtime: un job semanal consulta Azure Retail Prices API (pública, sin auth),
  AWS Price List bulk API (pública) y GCP Cloud Billing Catalog API (API key solo en CI) y genera JSON.
- Alternativa: correr **Infracost** sobre los `main.tf` en CI → costo base por patrón y por nube.
- Mostrar dos números, no diez: **"piso mensual con 0 tráfico"** y **"costo a X req/mensajes"** con un
  slider. Siempre con región y fecha del precio.

---

## 5. Pipeline de calidad (el moat)

| Check | Herramienta | Qué garantiza |
|---|---|---|
| Schema | Zod / JSON Schema en Astro content collections | Ningún patrón sin fuentes, sin `verified_at` o sin las 3 nubes |
| Formato/validez IaC | `terraform fmt -check`, `terraform validate` | El snippet compila |
| Lint por proveedor | `tflint` + rulesets azurerm/aws/google | SKUs, regiones y argumentos válidos |
| Seguridad | `checkov` o `trivy config` | El patrón "Zero Trust" pasa sus propias reglas (dogfooding) |
| Aserciones | `terraform test` con `mock_provider` (TF ≥ 1.7) | Atributos clave (`public_network_access_enabled = false`, etc.) sin deploy real |
| Versiones | Providers pinneados + Renovate | Saber cuándo un snippet quedó viejo |
| Links | `lychee` | Las fuentes oficiales siguen vivas |
| Frescura | Job que marca `verified_at > 180 días` y abre issue | Badge "verificado hace N días" en cada gotcha |
| Vigilancia | Action que lee Azure Updates / AWS What's New / GCP release notes y abre issue si matchea un servicio usado | Detectar cambios que invalidan contenido |

Opcional fase 3: deploy real nightly en cuentas sandbox vía OIDC (sin secretos) + `destroy`. Fuera
del guardrail de la *plataforma* (que sigue sin tocar nubes), pero cuesta plata: solo con sponsor.

---

## 6. Features que lo hacen increíble (priorizadas)

### Must (MVP)
1. **Comparador side-by-side** 2 o 3 columnas, con selector de nube por columna y URL compartible.
2. **Diagrama derivado de la topología abstracta** (mismo layout en todas las nubes; los nodos que
   *no* tienen equivalente se marcan visualmente — ese "hueco" es el insight).
3. **Gotchas tipados** (costo/seguridad/red/IAM/confiabilidad) con fuente oficial y fecha.
4. **Terraform diff** con copy, provider version y badge de CI verde.
5. **OG image por comparación** (clave para LinkedIn).
6. **Español + inglés** desde el día 1. Español es tu diferencial real para LATAM.

### Should (v1)
7. **Diccionario de capabilities** con búsqueda estática (Pagefind), incluyendo "no hay equivalente".
8. **Modo aprendizaje** (el *blind mode* de isbetter): quiz de arquitecturas y flashcards de gotchas,
   tageados por examen (AZ-104/305/700, SAA-C03, ACE/PCA). Democratización concreta: estudiar 3 certs a la vez.
9. **"Piso de costo"** con slider de carga.
10. **Dataset abierto** `/api/v1/*.json` + `llms.txt`.

### Could (v2+)
11. **MCP server read-only** sobre el dataset: que Claude/Copilot respondan "¿qué gotchas tiene migrar
    SQS a Service Bus?" citando Cloud Rosetta. Muy alineado con hacia dónde va el tooling, y costo $0.
12. **Matriz de decisión**: el usuario marca requisitos (private-only, scale-to-zero, FIFO) y ve qué
    combinación de SKUs lo cumple en cada nube y cuánto cuesta el piso.
13. **"Traducí mi Terraform"** con IA, solo BYOK client-side (patrón isbetter). Riesgo: alucinaciones
    contradicen el valor de "contenido verificado". Si se hace, mostrar siempre los gotchas curados al lado.
14. OCI como cuarta nube (milanm ya lo cubre en 1:1, acá sería por patrón).

### No hacer
- Cuentas de usuario, comentarios propios, DB: delegar en GitHub Discussions/Issues.
- Ejecutar o "simular" deploys contra APIs de proveedores.

---

## 7. Comunidad, gobernanza y licencias

- **Licencias:** código **MIT**; contenido **CC BY-SA 4.0** (protege que forks del contenido sigan abiertos
  y obliga atribución). Evitar FSL: para un proyecto de democratización, la licencia no tiene que generar dudas.
- **Íconos oficiales:** revisar términos de uso de los sets de íconos de Azure, AWS y GCP antes de
  embeberlos; documentarlo en `NOTICE`.
- **Contribuir un patrón** = un PR con 4 YAML + 3 carpetas de Terraform; template de issue
  "Proponer patrón" y "Reportar gotcha desactualizado" (este último es el más valioso).
- **CODEOWNERS por nube**: reviewers con experiencia real en cada proveedor (buscá 1 de AWS y 1 de GCP
  temprano; un proyecto multicloud mantenido solo por alguien de Azure va a tener sesgo visible).
- **Neutralidad:** guía editorial "sin ganador": cada gotcha dice qué cuesta y qué gana cada lado.
  Si se percibe como marketing de Azure, el proyecto pierde a la audiencia AWS/GCP.
- Hacktoberfest (octubre) y comunidades LATAM (AWS User Groups, Azure Tech Groups, GDG) como canal
  de primeras contribuciones: issues `good-first-issue` = "verificar gotcha X contra la doc actual".

---

## 8. Roadmap

| Fase | Duración | Entregable | Criterio de salida |
|---|---|---|---|
| 0. Fundaciones | 1–2 sem | Repo, schema de contenido, CI de calidad, layout del comparador | CI verde con 1 patrón dummy |
| 1. MVP | 3–4 sem | 3 patrones × 3 nubes, es/en, OG images, diccionario de ~30 capabilities | Todos los gotchas con fuente; checkov limpio |
| 2. Lanzamiento | 1 sem | Posts Fase 1–3 de LinkedIn + Show HN/Reddit r/AZURE r/aws r/googlecloud | Ver §9 |
| 3. Comunidad | continuo | Modo quiz, dataset `/api`, 5 patrones nuevos (al menos 2 de contribuidores) | Primer patrón 100% externo mergeado |
| 4. Plataforma | trimestre siguiente | MCP server, matriz de decisión, pricing job | — |

Patrones sugeridos para después del MVP (alto dolor, buen contenido de gotchas):
hub-and-spoke / landing zone networking; identidad federada CI/CD (OIDC GitHub → Entra / IAM / WIF);
DNS privado híbrido (Private DNS Resolver vs Route 53 Resolver vs Cloud DNS forwarding);
backup/DR cross-region; secretos (Key Vault vs Secrets Manager vs Secret Manager); egress control/NAT.
Los de red y DNS son donde tu perfil (AZ-700) suma autoridad.

---

## 9. Métricas de éxito (6 meses)

- Contribuidores externos con PR mergeado: ≥ 10 (señal de proyecto vivo, más que las estrellas).
- % de gotchas con `verified_at` < 180 días: ≥ 90%.
- Patrones cubiertos en las 3 nubes: ≥ 12.
- Links entrantes desde docs/blogs/PRs de terceros (la métrica de "referencia").
- Estrellas: vanity, pero ~1k es razonable como benchmark contra milanm/Cloud-Product-Mapping.

---

## 10. Riesgos

| Riesgo | Mitigación |
|---|---|
| Contenido desactualizado → pérdida de confianza | `verified_at`, badges, vigilancia automática de release notes |
| Sesgo pro-Azure | CODEOWNERS por nube, guía editorial neutral |
| Bus factor = 1 | Contenido como datos simples (YAML), cualquiera lo mantiene; docs de contribución |
| Colisión de nombre | Validar dominio/handle/repo antes del post de expectativa |
| Uso de íconos/marcas | Revisar términos; nunca sugerir afiliación con los vendors |
| Datos de clientes en ejemplos | Ejemplos con nombres genéricos (`contoso`, `example`), nunca IDs de tenant o suscripción reales |

---

## 11. Ajustes al plan de LinkedIn

- **Fase 1:** el copy es bueno. Sumar el gancho "comparar servicios 1:1 es una trampa: `aws_iam_role` no
  tiene equivalente directo en Azure" (ejemplo concreto > afirmación genérica).
- **Fase 2:** si no hay GCP en el MVP, no decir "entre Azure, AWS y GCP".
- **Fase 3:** **reescribir el punto 1** (Peek-Lock ≠ exactly-once, ver §3.3). Propuesta:
  > 1. Entrega: tanto SQS (visibility timeout) como Service Bus (peek-lock) son *at-least-once*. Tu
  > consumer tiene que ser idempotente en las dos. La diferencia está en lo que viene incluido:
  > Service Bus trae DLQ con `MaxDeliveryCount`, sessions para FIFO por clave y transacciones;
  > en SQS, FIFO es otro tipo de cola con límites de throughput propios.
- Agregar un post recurrente "Gotcha de la semana" con link a la comparación: alimenta contenido
  semanal sin esfuerzo extra y cada post apunta a una URL con OG image.

---

## Fuentes

- [isbetter.ai](https://isbetter.ai/) · [midudev/isbetter.ai en GitHub](https://github.com/midudev/isbetter.ai)
- [Google Cloud: AWS/Azure/GCP service comparison](https://docs.cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison)
- [AWS Prescriptive Guidance Patterns](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/welcome.html)
- [Datadog Provider Services Map](https://datadoghq.com/providerservicesmap)
- [milanm/Cloud-Product-Mapping](https://fr.github.com/milanm/Cloud-Product-Mapping)
- [CloudToolStack multi-cloud](https://cloudtoolstack.com/multi-cloud)
- [Holori Compare](https://calculator.holori.com/compare)
- [The cloud comparison chart lied to you (a little) — dev.to](https://dev.to/shane_law/the-cloud-comparison-chart-lied-to-you-a-little-39o9)
- [Infracost docs](https://infracost.io/docs)
- [Service Bus: Private endpoints (Premium)](https://learn.microsoft.com/azure/service-bus-messaging/private-link-service)
- [Service Bus: prevent message loss and duplicate processing](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-message-loss-and-duplicates)
- [Service Bus: secure your deployment](https://learn.microsoft.com/azure/service-bus-messaging/secure-service-bus)
- [Blob lifecycle management policies that delete blobs](https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-policy-delete)
- [Supabase free tier limits 2026](https://automationatlas.io/answers/supabase-free-tier-limits-2026/)
- [Next.js blog (releases)](https://nextjs.org/blog)
