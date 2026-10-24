# Convocatoria de revisores (F3-05)

Objetivo: que cada nube tenga al menos una persona con experiencia real que re-verifique gotchas y deje su
usuario en `verified_by`. Hoy los 74 gotchas los verificó solo el mantenedor y cada tarjeta lo dice
("sin revisor externo"). Los links usan `{SITE}` (`BRAND.site` en `src/lib/brand.ts`).

Lo que se pide es poco: revisar unos gotchas por mes contra la fuente oficial. La cola está en el issue
"Cola de revisión por nube" y se genera con `pnpm freshness --review`.

## Qué decir siempre

- Qué es: una referencia abierta de dónde se rompe la analogía entre Azure, AWS y GCP, con fuente oficial en cada afirmación.
- El problema: la verificación depende de una sola persona. Eso es una debilidad y se dice sin vueltas.
- Qué se pide: leer la fuente oficial, confirmar o corregir el texto, firmar con su usuario de GitHub.
- Qué se ofrece: aparecer como revisor en la tarjeta de cada gotcha que revise, y en `CODEOWNERS` de esa nube.
- Qué no se pide: escribir patrones, saber Terraform, ni comprometer tiempo fijo.

## AWS User Group / comunidad AWS

> Armé un sitio abierto que compara patrones completos entre Azure, AWS y GCP y marca dónde se rompe la analogía
> (por ejemplo, que un `Deny` por `aws:SourceVpce` te deja afuera de tu propio bucket). Cada gotcha cita la
> documentación oficial y tiene fecha de verificación.
>
> Hoy los verifico yo solo, y no es suficiente para AWS. Busco 1 o 2 personas con experiencia real en AWS que
> revisen gotchas de su nube contra la doc oficial: confirman o corrigen y firman con su usuario de GitHub.
> Con 30 minutos por mes alcanza. Los gotchas más severos (seguridad, IAM, red) están primero en la cola.
>
> Si te interesa: {SITE} · issue "Quiero revisar una nube" en el repo.

## GDG / comunidad Google Cloud (LATAM)

> Armé un sitio abierto que compara patrones entre Azure, AWS y GCP y señala dónde falla la analogía (por
> ejemplo, que en GCP soft delete viene activo y cobra 7 días extra por cada archivo efímero). Cada gotcha cita
> la documentación oficial.
>
> Busco 1 o 2 personas con experiencia en GCP que revisen gotchas de su nube contra la doc oficial y firmen con
> su usuario de GitHub. Con 30 minutos por mes alcanza, y los más severos van primero.
>
> Si te interesa: {SITE} · issue "Quiero revisar una nube" en el repo.

## LinkedIn (versión corta)

> Un sitio de referencia vale lo que vale su verificación, y la mía es de una sola persona. Busco revisores con
> experiencia real en AWS y GCP para Letra Chica, una comparación abierta de patrones entre nubes con fuentes
> oficiales. 30 minutos por mes, firmás con tu usuario de GitHub y quedás visible en cada gotcha que revises.
> {SITE}

## Respuesta tipo a quien se ofrece

> Gracias. Abrí el issue "Quiero revisar una nube" (nube y experiencia, sin nombres de clientes). Te sumo a
> `CODEOWNERS` de esa nube y empezás por la cola de revisión: elegí los gotchas más severos que conozcas,
> leé la fuente, corregí lo que haga falta y actualizá `verified_at` y `verified_by` en el PR.
