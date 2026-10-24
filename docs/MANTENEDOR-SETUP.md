# Setup del mantenedor (GitHub, Vercel, GCP)

Pasos que no se pueden hacer desde el repo: viven en la configuración de GitHub, Vercel y Google Cloud. Cada uno
dice qué habilita y cómo comprobar que quedó. Los comandos usan `gh` (GitHub CLI, ya autenticado con tu cuenta);
reemplazá `OWNER/REPO` si el repo cambia de lugar (hoy `santiagodaros/Cloud-Rosetta-Stone`).

## 1. Precios de GCP por API (hoy son manuales)

Habilita: que los 7 meters de GCP (`gcp-cloudsql-*`, `gcp-dns-*`) salgan de la Cloud Billing Catalog API en lugar de
los precios manuales del 2026-10-06.

1. Google Cloud Console → proyecto cualquiera (sirve uno personal; la Catalog API no factura) → **APIs & Services →
   Library** → habilitar **Cloud Billing API**.
2. **APIs & Services → Credentials → Create credentials → API key**.
3. En la key: **API restrictions → Restrict key → Cloud Billing API**. No pongas restricciones por IP: los runners
   de GitHub cambian de IP.
4. Guardala como secret (te pide el valor por stdin, no queda en el historial de la shell):

   ```bash
   gh secret set GCP_BILLING_API_KEY --repo OWNER/REPO
   ```

5. Probar. El script manda la key en el header `x-goog-api-key` (cambio de la rama `fix/review-hardening`, no
   probado con una key real todavía):

   ```bash
   gh workflow run prices.yml --repo OWNER/REPO
   gh run watch --repo OWNER/REPO
   ```

   Esperado: el log muestra `[api]` en los meters de GCP y, si algún precio cambió, se abre un PR
   `bot/prices-<fecha>`. Si falla con 403, la key no tiene la Cloud Billing API habilitada o está restringida a otra API.

## 2. Que Actions pueda abrir PRs

Habilita: que `prices.yml` abra el PR con `content/prices.json`.

Settings → Actions → General → Workflow permissions → **Allow GitHub Actions to create and approve pull requests**.

Nota: los PR abiertos con `GITHUB_TOKEN` no disparan CI; cerralo y reabrilo para validarlo.

## 3. Rebuild semanal en Vercel

Habilita: que el "verificado hace N días" y el gotcha del día no queden congelados.

1. Vercel → proyecto → Settings → Environment Variables: `VERCEL_DEEP_CLONE=true` (el changelog usa `git log`; sin
   historial completo, `/changes` queda vacío).
2. Vercel → Settings → Git → **Deploy Hooks** → crear uno para la rama `main`.
3. ```bash
   gh secret set VERCEL_DEPLOY_HOOK_URL --repo OWNER/REPO
   ```

Comprobar: `gh workflow run rebuild.yml --repo OWNER/REPO` y ver un deploy nuevo en Vercel.

> Aplicado el 2026-10-24 con `gh`: descripción y topics del repo, Discussions y los labels `dependencies`, `terraform`, `reviewer` y `review-queue`.
> Pendiente: el reporte privado de vulnerabilidades (la API devolvió 404; activarlo en Settings → Code security) y "Allow GitHub Actions to create and approve pull requests" (sección 2), que se dejó sin tocar a propósito porque es un interruptor de seguridad.

## 4. Repo: topics, Discussions, reporte privado de vulnerabilidades

```bash
gh repo edit OWNER/REPO --enable-discussions \
  --add-topic hacktoberfest --add-topic multicloud --add-topic azure --add-topic aws --add-topic gcp \
  --add-topic terraform --add-topic cloud-architecture --add-topic spanish
gh api -X PUT repos/OWNER/REPO/private-vulnerability-reporting
```

El template de issues enlaza a Discussions y `SECURITY.md` referencia el reporte privado, así que sin esto ambos
links están rotos.

## 5. Labels que usan los workflows y los templates

```bash
for l in freshness content reviewer review-queue dependencies terraform; do
  gh label create "$l" --repo OWNER/REPO 2>/dev/null || echo "ya existe: $l"
done
gh label create "good first issue" --repo OWNER/REPO 2>/dev/null || true
```

`freshness` y `review-queue` los usan los issues automáticos de `freshness.yml`; `reviewer` y `content` los trae el
template "Quiero revisar una nube".

## 6. Instalar Renovate (bot de dependencias)

Habilita: PRs semanales de actualización de npm, acciones de GitHub (con el SHA fijado), providers de Terraform y
plugins de tflint, según `renovate.json`. Es el único bot de dependencias del repo: se descartó Dependabot, así que
**hasta instalar la app no se actualiza nada solo**.

1. Instalá la app de Renovate en https://github.com/apps/renovate y dale acceso a este repo.
2. Renovate abre un PR de onboarding en el primer ciclo; revisalo y mergealo.
3. Comprobá que los PRs lleguen con el label `dependencies` (y `terraform` para los providers).

Nota: el CI es la red de seguridad de esos PRs (validate, test, tflint y checkov) y desde que el repo es público vuelve a correr en cada PR. Pasá siempre por los checks antes de mergear un PR de Renovate.

## 7. Medir retención (F4-21): decidido, solo métricas proxy

Decisión del 2026-10-24: no se agrega analytics (ni Cloudflare Web Analytics ni otro). El "sin trackers, $0" es un
diferencial del proyecto (D8) y todavía no hay tráfico que justifique romperlo. Las señales que se miran son las que ya
da GitHub, sin instalar nada:

```bash
gh api repos/OWNER/REPO/traffic/views                # vistas y visitantes únicos, últimos 14 días
gh api repos/OWNER/REPO/traffic/clones               # clones
gh api repos/OWNER/REPO/traffic/popular/referrers    # de dónde llega la gente
gh api repos/OWNER/REPO/traffic/popular/paths        # qué páginas del repo leen
gh api repos/OWNER/REPO --jq '{stars:.stargazers_count, forks:.forks_count, watchers:.subscribers_count}'
```

GitHub solo guarda 14 días de tráfico: para tener historia hay que anotar los números cada semana. Se suman los PRs y
issues de gente externa. Se revisa la decisión si el proyecto llega a ~1.000 estrellas (el benchmark de `docs/PLAN.md`,
sección 5) o si aparece una pregunta que estas señales no puedan responder.

## 8. Visibilidad del repo (era privado; pasó a público el 2026-10-24)

> **Hecho el 2026-10-24.** El repo es público, el reporte privado de vulnerabilidades está activado y `main` tiene una protección mínima (PR obligatorio sin aprobaciones, sin force-push ni borrado). `main` exige además los checks "Contenido + sitio" y "Checkov (seguridad IaC)" (los más deterministas; no se exigen los que dependen de la red, como los links o los precios, para que un fallo de conexión no bloquee un merge). Pendiente: revisar el acceso de la app de Renovate. Lo que sigue es el análisis que llevó a la decisión.


Verificado el 2026-10-24 con `gh repo view`: `visibility: PRIVATE`. Eso explica varias cosas que parecían problemas separados:

- **La convocatoria de revisores no llega a nadie.** Los issues #25 y #26, `CODEOWNERS`, los `good first issue` y Hacktoberfest apuntan a gente externa, que con el repo privado no ve nada salvo que la invites como colaboradora.
- **El reporte privado de vulnerabilidades da 404.** Esa función solo existe en repos públicos (`SECURITY.md` la menciona).
- **No hay protección de ramas ni rulesets** ("Upgrade to GitHub Pro or make this repository public").
- **El CI bloqueado** ("recent account payments have failed or your spending limit needs to be increased") es un límite de la cuenta por usar Actions en repos privados. Los repos públicos tienen minutos de Actions gratuitos.

El sitio ya es público y el README presenta el proyecto como abierto (código MIT, contenido CC BY-SA), así que lo coherente es publicar el repo. Auditoría previa, hecha el 2026-10-24:

- **Secretos:** ningún patrón de credenciales (AWS, GitHub, Slack, claves privadas, API keys) en los 119 commits del historial, ni archivos de credenciales versionados.
- **Licencias:** `LICENSE` (MIT) y `LICENSE-CONTENT.md` (CC BY-SA 4.0) ya están. Los 63 archivos de `.claude/skills/` son de terceros (MIT, © 2025 Corey Haines) y no tenían su aviso: se agregó a `NOTICE.md`.
- **Contenido interno:** no hay datos de clientes, tenants ni cuentas (el repo no tiene `.private-terms`). `.claude/settings.json` nombra plugins de un marketplace privado: es inocuo, pero conviene saberlo.

Qué cambia al publicar: el CI de GitHub vuelve a correr sin costo, se habilitan el reporte privado de vulnerabilidades y la protección de ramas, y los revisores externos pueden ver los issues y abrir PRs. Es reversible (se puede volver a privado), pero los forks y clones que alguien haya hecho mientras fue público quedan.

```bash
gh repo edit OWNER/REPO --visibility public --accept-visibility-change-consequences
```

Después: activar el reporte privado de vulnerabilidades (Settings → Code security), proteger `main` (exigir PR y los checks del CI), correr el CI a mano sobre `main` para confirmar el Terraform y revisar que Renovate tenga acceso.

## Orden sugerido

8 → 2 → 1 → 5 → 4 → 3 → 6 → 7. Lo primero deja que `prices.yml` funcione; los labels evitan que los workflows fallen al crear
issues.
