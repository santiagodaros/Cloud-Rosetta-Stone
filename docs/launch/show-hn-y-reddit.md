# Show HN y Reddit

## Show HN

Publicar un martes o miércoles entre las 8 y las 10 a.m. hora del Pacífico. Postealo vos (el autor) y
quedate respondiendo las primeras 2–3 horas. Nada de pedir votos, ni en HN ni afuera.

**Título** (≤ 80 caracteres):

```text
Show HN: Letra Chica – where the analogy breaks between AWS, Azure and GCP
```

**URL:** `{SITE}/en/` (no el repo: HN prefiere algo que se pueda usar sin clonar).

**Primer comentario (texto del autor):**

```text
Hi HN, I'm a cloud infrastructure engineer, mostly on Azure. Every time I design something on AWS or GCP the equivalence tables tell me which service to use, but not what breaks when I translate the architecture.

Letra Chica ("the fine print" in Spanish) compares full patterns instead of individual services. Each pattern has the same topology on all three clouds, what implements each role, a cost model, and the fine print: documented differences, each with an official source and a verification date. A few examples:

- Azure lifecycle prefix filters must start with the container name. The "incoming/" filter that works on S3 creates fine on Azure and never deletes anything.
- Cloud SQL for PostgreSQL IAM users for service accounts drop the ".gserviceaccount.com" suffix.
- On Lambda + SQS, the queue's visibility timeout should be at least 6x the function timeout, or you get duplicates while the first invocation is still running.

How it's built: the content is YAML in the repo, validated with a Zod schema that only accepts sources from official documentation domains. The site is static (Astro), diagrams are laid out at build time with ELK so the three clouds share the same layout. Every Terraform module runs fmt, validate, terraform test with mock providers (no credentials), tflint and checkov in CI. Renovate bumps providers, so when a provider renames an attribute, CI goes red on that snippet. That already happened twice with azurerm 5.

Limitations: mock-provider tests don't catch apply-time errors (quotas, regional availability), and it's 5 patterns today. Spanish is the primary language, English is complete.

Code is MIT, content CC BY-SA, and there's a JSON dataset. I'd love feedback on which patterns to add next and on any fine print I got wrong.
```

---

## Reddit

Leé las reglas de cada subreddit antes de postear: varios exigen flair, limitan la autopromoción o tienen
un hilo semanal para esto. Si un sub no permite links propios, no lo fuerces: compartí un gotcha como texto
y ofrecé el link solo si lo piden. Espaciá los posts (no todos el mismo día) y no copies el mismo texto.

### r/AZURE · r/aws · r/googlecloud

Mismo formato, con el gotcha principal de la nube del sub. Ejemplo para **r/AZURE**:

**Título:**
```text
Lifecycle policies: the prefix filter has to start with the container name (and it fails silently if it doesn't)
```

**Cuerpo:**
```text
Ran into this while comparing the same "upload files that expire after N days" pattern across Azure, AWS and GCP.

In Azure Blob lifecycle management, prefixMatch is "container/path", not just the path. An "incoming/" filter (which is what you'd write on S3 or GCS) matches a container named "incoming", so the policy deploys without errors and never deletes anything.

Two related ones in the same pattern:
- Lifecycle can take up to 24 h to apply, so it's not a security control.
- With blob soft delete enabled, "delete" leaves the blob soft-deleted for the retention period, so your effective cost TTL is ttl_days + soft-delete days.

I'm collecting these in an open project with official sources and tested Terraform per cloud: {SITE}/en/patterns/object-storage-ttl/azure-vs-aws/
Happy to hear what I missed.
```

Para **r/aws**: arrancá con `sourcevpce-lockout` o `visibility-timeout-6x`. Para **r/googlecloud**:
`soft-delete-default-7-days` o `iam-sa-username-trim`.

### r/Terraform

Ángulo: el pipeline de calidad, no el contenido.

**Título:**
```text
Testing Terraform snippets in docs without credentials: validate + terraform test with mock providers + checkov
```

**Cuerpo:** explicá el setup (`mock_provider`, `command = plan`, aserciones sobre lo que el patrón promete,
skips de checkov justificados en el código, Renovate para providers). Mencioná los dos cambios de schema de
azurerm 5 que atrapó `validate`. Link al repo al final.

### r/devops · r/sysadmin

Solo si el sub lo permite. Ángulo: "74 diferencias entre nubes que no están en las tablas de equivalencias",
con 3 ejemplos de nubes distintas.

### Comunidades en español (r/devsarg, grupos de AWS UG / Azure / GDG LATAM)

Español, tono cercano, y el diferencial explícito: contenido técnico multicloud en español, con fuentes.
Ofrecé contar el proyecto en una meetup; es mejor canal que el post.
