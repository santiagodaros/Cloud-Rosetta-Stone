# Kit de lanzamiento — Fase 2

Todo lo necesario para lanzar Letra Chica. Los textos se pegan tal cual; los links usan `{SITE}`, que es
`BRAND.site` en [`src/lib/brand.ts`](../../src/lib/brand.ts).

| Archivo | Para qué |
|---|---|
| [`linkedin.md`](./linkedin.md) | 3 posts (expectativa, lanzamiento, letra chica) × 2 variantes, más versión en inglés |
| [`show-hn-y-reddit.md`](./show-hn-y-reddit.md) | Show HN (título + comentario del autor) y posts por subreddit |
| [`gotcha-de-la-semana.md`](./gotcha-de-la-semana.md) | 12 semanas de posts generados desde el contenido (`pnpm launch:weekly`) |
| [`convocatoria-revisores.md`](./convocatoria-revisores.md) | Convocatoria de revisores por nube (AWS UG, GDG LATAM, LinkedIn) y respuesta tipo |
| [`assets/`](./assets/) | Screenshots para los posts y `social-preview.png` para el repo |

## Checklist antes del día L

| # | Tarea | Dónde | Estado |
|---|---|---|---|
| 1 | Mergear el PR de Fase 1 + 2 | GitHub | ☐ |
| 2 | (Diferido) Renombrar el repo. Hoy no es necesario: todo usa la URL actual. Si se renombra, actualizar `BRAND.repo` y `BRAND.site` y correr `pnpm launch:weekly` | Settings → General / `src/lib/brand.ts` | — |
| 3 | Confirmar que `pnpm launch:weekly` apunta a la URL publicada | `docs/launch/gotcha-de-la-semana.md` | ☐ |
| 4 | Proyecto en Vercel conectado al repo; env `VERCEL_DEEP_CLONE=true`; Deploy Hook de `main` guardado como secret `VERCEL_DEPLOY_HOOK_URL` | Vercel → Settings / GitHub → Secrets | ◐ (proyecto creado) |
| 5 | Verificar que los links levantan la OG image | [LinkedIn Post Inspector](https://www.linkedin.com/post-inspector/) | ☐ |
| 6 | Descripción, website y topics del repo (`multicloud`, `azure`, `aws`, `gcp`, `terraform`, `cloud-architecture`, `spanish`) | Repo → About | ☐ |
| 7 | Subir `assets/social-preview.png` | Settings → General → Social preview | ☐ |
| 8 | Habilitar Discussions y *private vulnerability reporting* | Settings | ☐ |
| 9 | (Opcional) Dominio propio: verificar disponibilidad de `letrachica.dev` / `letrachica.cloud`, agregarlo en Vercel → Domains y actualizar `BRAND.site` | Registrar + Vercel → Domains | ☐ |
| 10 | Revisar que los 10 `good first issue` sigan vigentes | Issues | ☐ |

> El sitio vive en `https://cloud-rosetta-stone.vercel.app/`. Si el nombre viejo molesta en los posts, un
> dominio propio (paso 9) lo resuelve sin renombrar el repo.
>
> El nombre: se descartó "Cloud Rosetta Stone" por colisión con
> [lensabillion/cloud-rosetta](https://github.com/lensabillion/cloud-rosetta) (mismo concepto, orientado a
> certificaciones), [gordonmurray/cloud-rosetta](https://github.com/gordonmurray/cloud-rosetta) (costos de
> Terraform), un post previo en dev.to con ese nombre, y la marca registrada "Rosetta Stone".

## Calendario

| Día | Acción | Canal |
|---|---|---|
| L−7 | Post 1 (expectativa) | LinkedIn |
| L (martes o miércoles) | Post 2 (lanzamiento) por la mañana | LinkedIn |
| L, 8–10 a.m. PT | Show HN y quedarse respondiendo | Hacker News |
| L+1 | r/AZURE | Reddit |
| L+2 | r/Terraform | Reddit |
| L+3 | Post 3 (letra chica) | LinkedIn |
| L+4 | r/aws | Reddit |
| L+6 | r/googlecloud | Reddit |
| L+7 en adelante | "Gotcha de la semana" (12 semanas) | LinkedIn |
| Continuo | Ofrecer charla en AWS UG / Azure / GDG LATAM | Meetups |

## Qué medir (primeras 4 semanas)

- PRs externos abiertos y mergeados (objetivo de salida de la Fase 2: el primero).
- Issues de "gotcha desactualizado": son señal de uso real, no de problema.
- Visitas a `/es/` vs `/en/` (si se agrega analítica, que sea sin cookies).
- Comentarios con patrones pedidos: alimentan el backlog de la Fase 3.
