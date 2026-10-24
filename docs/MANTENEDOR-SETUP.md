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

## 6. Decisión pendiente: medir retención (F4-21)

Cloudflare Web Analytics (sin cookies, sin perfilado) o solo métricas proxy (suscriptores del feed Atom, tráfico de
GitHub, descargas del dataset). Si se adopta analytics, actualizar README y el diferencial D8 ("sin trackers") en
`docs/PLAN.md`. Mientras no se decida, no se agrega nada.

## Orden sugerido

2 → 1 → 5 → 4 → 3. Lo primero deja que `prices.yml` funcione; los labels evitan que los workflows fallen al crear
issues.
